# %% [markdown]
# # MacroRunner – does looking at a photo several ways help?
#
# Test-time augmentation (TTA): the app runs the model on a few views of the
# same photo (the photo, its mirror image, a closer centre crop…) and averages
# the probabilities. This notebook measures how much that raises dish
# accuracy on the **same test photos** the training run reported, with the
# **trained checkpoint**, without training again.
#
# **On Google Colab**
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. Fill in where the training run is: `RUN_DIR` on your Drive, or the Drive
#    file ids of its `checkpoint.keras`, `splits.csv` and `dishes.txt` when
#    the folder was shared with you by link.
# 3. *Runtime → Run all*. The four datasets download again (about 10–15
#    minutes); the evaluation itself takes a few minutes on the GPU.
#
# The views are the ones the app can make cheaply from one photo. Each view
# costs one more model run on the phone.

# %%
import os
import sys
import time

RUN_DIR = ''          # e.g. '/content/drive/MyDrive/macrorunner_train/efficientnetb0_finetune'
CHECKPOINT_ID = ''    # Drive file ids, used when RUN_DIR is empty
SPLITS_ID = ''
DISHES_ID = ''
BATCH = 16           # photos per step; each brings 4 views, so 64 images

INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
WORK = os.environ.get('WORK_DIR', '/content/tta')
SHRUNK_DIR = os.environ.get('SHRUNK_DIR', '/tmp/shrunk')
ON_COLAB = 'google.colab' in sys.modules
KAGGLE_DATASETS = [
    'lnguynanhnht/20foodvn',
    'quandang/vietnamese-foods',
    'sonbui25/vinafood21',
    'thomasnguyen6868/vietfood68',
]
os.makedirs(WORK, exist_ok=True)

# %% [markdown]
# ## The training run's files and the photos

# %%
import subprocess


def fetch(file_id, name):
    """A Drive file shared by link, saved into WORK."""
    target = os.path.join(WORK, name)
    if not os.path.exists(target):
        subprocess.run(['curl', '-sL', '-o', target,
                        'https://drive.usercontent.google.com/download?id='
                        f'{file_id}&export=download&confirm=t'], check=True)
    return target


if RUN_DIR:
    if ON_COLAB and RUN_DIR.startswith('/content/drive'):
        from google.colab import drive
        drive.mount('/content/drive')
    CHECKPOINT = os.path.join(RUN_DIR, 'checkpoint.keras')
    SPLITS = os.path.join(RUN_DIR, 'splits.csv')
    DISHES_TXT = os.path.join(RUN_DIR, 'dishes.txt')
elif CHECKPOINT_ID:
    CHECKPOINT = fetch(CHECKPOINT_ID, 'checkpoint.keras')
    SPLITS = fetch(SPLITS_ID, 'splits.csv')
    DISHES_TXT = fetch(DISHES_ID, 'dishes.txt')
else:
    CHECKPOINT = os.environ['CHECKPOINT']
    SPLITS = os.environ['SPLITS']
    DISHES_TXT = os.environ['DISHES_TXT']

if ON_COLAB:
    # Same download and folder names as the training notebook, so the paths
    # in splits.csv point at the same photos.
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', '-U',
                    'kagglehub'], check=True)
    import kagglehub
    INPUT_ROOT = '/content/datasets'
    os.makedirs(INPUT_ROOT, exist_ok=True)
    for ref in KAGGLE_DATASETS:
        started = time.time()
        print(f'Downloading {ref} ...', flush=True)
        path = kagglehub.dataset_download(ref)
        link = os.path.join(INPUT_ROOT, ref.split('/')[1])
        # A link left from an earlier session may point at a deleted cache.
        if os.path.islink(link) and os.path.realpath(link) != os.path.realpath(path):
            os.remove(link)
        if not os.path.lexists(link):
            os.symlink(path, link)
        print(f'  done in {time.time() - started:.0f} s: {path}', flush=True)

# %% [markdown]
# ## Test photos, prepared exactly like the training run's test set
# Each photo is shrunk once to a 384-pixel short side (upright, as in the
# training notebook); the views below are cut from that copy.

# %%
import csv
import hashlib
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageOps

SHRUNK_SIDE = 384
os.makedirs(SHRUNK_DIR, exist_ok=True)


def shrink(path):
    """Same as the training notebook's shrink()."""
    digest = hashlib.md5(path.encode('utf-8')).hexdigest()
    target = os.path.join(SHRUNK_DIR, f'{digest}.jpg')
    if os.path.exists(target):
        return target
    try:
        with Image.open(path) as im:
            im.draft('RGB', (SHRUNK_SIDE, SHRUNK_SIDE))
            im = ImageOps.exif_transpose(im).convert('RGB')
            scale = SHRUNK_SIDE / min(im.size)
            if scale < 1:
                im = im.resize((max(1, round(im.width * scale)),
                                max(1, round(im.height * scale))),
                               Image.BILINEAR)
            im.save(target, quality=90)
    except Exception:
        return None
    return target


SLUGS = [ref.split('/')[1] for ref in KAGGLE_DATASETS]


def locate(path):
    """[path] if it exists, else the same file under this session's
    INPUT_ROOT. splits.csv keeps the paths of the training session, which
    may have been Kaggle (/kaggle/input/...) or another Colab session."""
    if os.path.exists(path):
        return path
    parts = path.replace('\\', '/').split('/')
    for i, part in enumerate(parts):
        if part in SLUGS:
            moved = os.path.join(INPUT_ROOT, part, *parts[i + 1:])
            if os.path.exists(moved):
                return moved
    return None


OUTPUTS = [line.strip() for line in open(DISHES_TXT, encoding='utf-8')
           if line.strip()]
INDEX = {code: i for i, code in enumerate(OUTPUTS)}
with open(SPLITS, encoding='utf-8') as f:
    rows = [r for r in csv.DictReader(f) if r['split'] == 'test']
found = [locate(r['file']) for r in rows]
missing = [r['file'] for r, f in zip(rows, found) if f is None]
if missing:
    print(f'{len(missing)} test photos not found, e.g. {missing[0]}')
    for slug in SLUGS:
        root = os.path.join(INPUT_ROOT, slug)
        print(f'  {root}:', sorted(os.listdir(root))[:5]
              if os.path.isdir(root) else 'missing')
if len(missing) == len(rows):
    raise RuntimeError(
        'None of the test photos were found. Check that the download cell '
        'above finished for all four datasets, then run this cell again.')
started = time.time()
with ThreadPoolExecutor(32) as pool:
    files = list(pool.map(lambda f: f and shrink(f), found))
test = [(file, INDEX[r['dish']]) for r, file in zip(rows, files)
        if file is not None and r['dish'] in INDEX]
print(f'{len(test)} of {len(rows)} test photos ready in '
      f'{time.time() - started:.0f} s', flush=True)
if len(test) < len(rows):
    print('Missing photos make the numbers differ from the training run.')

# %% [markdown]
# ## Views
# - `photo`: the centre square, as the app reads it today;
# - `mirror`: the same, flipped left to right;
# - `closer`: the centre 80% of that square, a little closer;
# - `closer mirror`: that, flipped.

# %%
import numpy as np
import tensorflow as tf
from tensorflow import keras

IMG = 224
VIEWS = ['photo', 'mirror', 'closer', 'closer mirror']


def load_views(path):
    image = tf.io.decode_image(tf.io.read_file(path), channels=3,
                               expand_animations=False)
    image = tf.cast(image, tf.float32)
    h, w = tf.shape(image)[0], tf.shape(image)[1]
    side = tf.minimum(h, w)
    square = tf.image.crop_to_bounding_box(
        image, (h - side) // 2, (w - side) // 2, side, side)
    inner = tf.cast(tf.cast(side, tf.float32) * 0.8, tf.int32)
    closer = tf.image.crop_to_bounding_box(
        square, (side - inner) // 2, (side - inner) // 2, inner, inner)
    photo = tf.image.resize(square, [IMG, IMG], method='bilinear')
    closer = tf.image.resize(closer, [IMG, IMG], method='bilinear')
    views = tf.stack([photo, tf.image.flip_left_right(photo),
                      closer, tf.image.flip_left_right(closer)])
    return tf.clip_by_value(views, 0.0, 255.0)


model = keras.models.load_model(CHECKPOINT, compile=False)
# A compiled graph needs far less GPU memory than calling the model eagerly.
infer = tf.function(lambda images: model(images, training=False)['dish'])
paths = [file for file, _ in test]
truth = np.array([dish for _, dish in test])
data = (tf.data.Dataset.from_tensor_slices(paths)
        .map(load_views, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(BATCH).prefetch(tf.data.AUTOTUNE))
probs = []   # [photos, views, dishes]
started = time.time()
for batch in data:
    n = batch.shape[0]
    out = infer(tf.reshape(batch, [-1, IMG, IMG, 3]))
    probs.append(tf.reshape(out, [n, len(VIEWS), -1]).numpy())
probs = np.concatenate(probs)
print(f'Ran {len(VIEWS)} views of {len(paths)} photos in '
      f'{time.time() - started:.0f} s')

# %% [markdown]
# ## Results
# Accuracy for each set of views, averaging their probabilities. The first
# row should match the training run's test top-1.

# %%
import json

COMBOS = {
    'photo (today)': [0],
    'photo + mirror': [0, 1],
    'photo + closer': [0, 2],
    'all four views': [0, 1, 2, 3],
}


def scores(p):
    top3 = np.argsort(-p, axis=1)[:, :3]
    top1 = top3[:, 0] == truth
    per_dish = {code: round(float(top1[truth == i].mean()), 3)
                for i, code in enumerate(OUTPUTS) if (truth == i).any()}
    return {'top1': float(top1.mean()),
            'top3': float((top3 == truth[:, None]).any(axis=1).mean()),
            'per_dish': per_dish}


results = {}
for name, views in COMBOS.items():
    results[name] = {'views': [VIEWS[v] for v in views], 'model_runs': len(views),
                     **scores(probs[:, views].mean(axis=1))}
base = results['photo (today)']
print(f"{'Views':<18}{'runs':>5}{'top-1':>8}{'top-3':>8}{'change':>9}"
      f"{'cơm phần':>10}{'khac':>7}")
for name, r in results.items():
    print(f"{name:<18}{r['model_runs']:>5}{r['top1'] * 100:>7.1f}%"
          f"{r['top3'] * 100:>7.1f}%{(r['top1'] - base['top1']) * 100:>+8.1f}"
          f"{r['per_dish'].get('com_phan', 0) * 100:>9.1f}%"
          f"{r['per_dish'].get('khac', 0) * 100:>6.1f}%")

out_dir = RUN_DIR or WORK
if ON_COLAB and not RUN_DIR:
    # Keep the numbers when the session ends.
    from google.colab import drive
    drive.mount('/content/drive')
    out_dir = '/content/drive/MyDrive/macrorunner_train'
    os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, 'results_tta.json'), 'w') as f:
    json.dump({'checkpoint': CHECKPOINT, 'photos': len(paths), **results}, f,
              indent=2)
print('Saved', os.path.join(out_dir, 'results_tta.json'))
