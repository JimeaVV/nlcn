# %% [markdown]
# # MacroRunner – train the meat classifier
#
# Trains the third model of `docs/MODEL_CONTRACT.md` (contract 1.8, §9): a
# small classifier that looks again at each meat box the plate detector
# (§7) finds and says which meat it is. The detector finds the meat well
# but often names the wrong one: on the 459 FoodInsSeg test plates, chicken
# breast came out as pork, fish or beef. Here a MobileNetV3 sees only the
# box, at 224×224, so it can spend all its attention on the meat itself.
#
# Classes: the detector's seven meats and `khac`, anything else (rice, egg,
# tofu, an empty patch of plate), so the app can tell a box that is not meat
# at all. The result is the three files the app reads from `assets/models/`:
# `meat_classifier.tflite`, `meat_classes.txt` and `MEAT_CARD.md`.
#
# Data: the same boxes the detector trains on, cut out of the photos with a
# margin: VietFood67's boxes, FoodInsSeg's pieces (touching pieces of one
# food joined into one box, as for the detector) and MyFood's chicken
# breast and steak masks. Each keeps its own train/val/test split, the same
# as the detector's, so its test photos stay unseen by both models.
#
# Photos are first shrunk so the long side is 512 px, the detector's input:
# the app cuts the boxes out of that same small copy, so the crops look the
# same in training and in the app.
#
# **On Kaggle** (recommended: the data is already there)
# 1. *Add Input*: the dataset `thomasnguyen6868/vietfood68`.
# 2. *Settings*: Accelerator GPU T4 x2 or P100 (one GPU is used), Internet
#    **on** (FoodInsSeg comes from Google Drive, MyFood from Zenodo).
# 3. Run once with `QUICK_TEST = True` (10–15 minutes, most of it reading
#    VietFood67's labels), then set `QUICK_TEST = False` and
#    *Save Version → Save & Run All*. The files are in the *Output* tab.
#    Expect about 1–1.5 hours in all.
#
# **On Google Colab**
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. The Kaggle key in *Secrets*, as for the other notebooks:
#    `KAGGLE_API_TOKEN` with the `KGAT_...` value, notebook access on.
# 3. *Runtime → Run all*, allow Google Drive. VietFood67 downloads once per
#    session (26 GB, about 15 minutes). Results go to Google Drive, folder
#    `macrorunner_train/meat_classifier`.
#
# VietFood67 and FoodInsSeg are CC BY-NC-SA 4.0; MyFood is CC BY 4.0.

# %%
import os
import sys
import time

NOTEBOOK_STARTED = time.time()


def stage(text):
    """One timestamped log line, so a long run shows where it is."""
    minutes = (time.time() - NOTEBOOK_STARTED) / 60
    print(f'[{minutes:6.1f} min] {text}', flush=True)


QUICK_TEST = True        # True: 400 crops, 1 epoch per phase.
# 'mobilenetv3large' (6 MB as float16, 6.5 ms a box on a laptop CPU) or
# 'mobilenetv3small' (about 2 MB, a third of the work, likely a few points
# worse; not yet compared).
BACKBONE = os.environ.get('BACKBONE', 'mobilenetv3large')
IMG = 224                # the classifier's input; the app reads it from the file
PHOTO_SIDE = 512         # photos shrunk to this long side first (detector input)
# The box is grown by this share of its width and height on each side before
# cutting, so the crop shows the meat's edge and a little of the plate. The
# app reads it from MEAT_CARD.md (`crop_pad`).
CROP_PAD = 0.10
# Training moves the box by up to this share of its size and makes it up to
# this much bigger or smaller, like the detector's boxes are off.
BOX_SHIFT = 0.10
BOX_SCALE = 0.25
EPOCHS_HEAD = 1 if QUICK_TEST else 2     # backbone frozen
EPOCHS_FINE = 1 if QUICK_TEST else 12    # all layers
BATCH = 16 if QUICK_TEST else 64
LEARNING_RATE = 3e-4     # fine-tuning, falling to 0 on a cosine
SEED = 0
# Classes with fewer train crops are repeated up to this many (random crops
# make the repeats differ), and the largest are cut to MAX_PER_CLASS.
MIN_PER_CLASS = 0 if QUICK_TEST else 2000
MAX_PER_CLASS = 50 if QUICK_TEST else 12000
# `khac` crops (other foods, empty plate) as a share of the meat crops.
OTHER_SHARE = 0.5
# Share of `khac` crops that are empty patches of FoodInsSeg photos, where
# every food is outlined, so a patch away from all of them is plate or table.
BACKGROUND_SHARE = 0.2
# Boxes smaller than this share of the photo's side are left out: the
# detector seldom reports them, and at 512 px they are a few pixels.
MIN_BOX = 0.04
# FoodInsSeg: touching pieces of one food are one box, as for the detector
# (its JOIN_GAP).
JOIN_GAP = 0.02
WEIGHTS = os.environ.get('WEIGHTS', 'imagenet')   # 'none' in the smoke test
# float16 maths on the GPU's tensor cores; the exported model is float32.
MIXED_PRECISION = os.environ.get('MIXED_PRECISION', 'gpu')

ON_COLAB = 'google.colab' in sys.modules
ON_KAGGLE = bool(os.environ.get('KAGGLE_KERNEL_RUN_TYPE'))
INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/kaggle/working')
WORK_DIR = os.environ.get('WORK_DIR', '/tmp/meat_data')
VF67_REF = 'thomasnguyen6868/vietfood68'
MYFOOD_URL = ('https://zenodo.org/records/4041488/files/'
              'MyFood%20Dataset.zip?download=1')
DOWNLOAD_MYFOOD = os.environ.get('DOWNLOAD_MYFOOD', '1') == '1'
FOODINSSEG_ID = '1Wa8_j4flJOMM6a2QGpiPga0r1GC__Rg2'   # 1.3 GB zip
DOWNLOAD_FOODINSSEG = os.environ.get('DOWNLOAD_FOODINSSEG', '1') == '1'
COLAB_ROOT = os.environ.get('COLAB_ROOT', '/content')

# %% [markdown]
# ## Setup: Drive, the datasets

# %%
import shutil
import subprocess


def load_gdown():
    try:
        import gdown
    except ImportError:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'gdown'],
                       check=True)
        import gdown
    return gdown


if ON_COLAB:
    from google.colab import drive
    print('Allow Google Drive access in the window that opens now.', flush=True)
    drive.mount(os.path.join(COLAB_ROOT, 'drive'))
    OUTPUT_DIR = os.path.join(COLAB_ROOT, 'drive', 'MyDrive', 'macrorunner_train',
                              'meat_classifier' + ('_quick' if QUICK_TEST else ''))
    WORK_DIR = os.path.join(COLAB_ROOT, 'meat_data')

    from google.colab import userdata
    for key in ('KAGGLE_USERNAME', 'KAGGLE_KEY', 'KAGGLE_API_TOKEN'):
        try:
            value = userdata.get(key)
        except Exception:   # not added, or notebook access is off
            value = None
        if value:
            os.environ[key] = value
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', '-U',
                    'kagglehub'], check=True)
    import kagglehub
    INPUT_ROOT = os.path.join(COLAB_ROOT, 'datasets')
    os.makedirs(INPUT_ROOT, exist_ok=True)
    link = os.path.join(INPUT_ROOT, VF67_REF.split('/')[1])
    if not os.path.lexists(link):
        stage(f'Downloading {VF67_REF} (26 GB) ...')
        try:
            path = kagglehub.dataset_download(VF67_REF)
        except Exception as error:
            raise RuntimeError(
                f'Could not download {VF67_REF}: {error}. Check the Colab '
                'secret KAGGLE_API_TOKEN, with notebook access on.') from error
        os.symlink(path, link)

EXTRA_ROOT = os.path.join(WORK_DIR, 'extra')
os.makedirs(EXTRA_ROOT, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def download_zip(name, fetch):
    """Unzips what [fetch] saves to EXTRA_ROOT/[name], once."""
    import zipfile
    folder = os.path.join(EXTRA_ROOT, name)
    if os.path.isdir(folder):
        return
    stage(f'Downloading {name} ...')
    fetch(folder + '.zip')
    with zipfile.ZipFile(folder + '.zip') as z:
        z.extractall(folder + '.part')
    os.replace(folder + '.part', folder)
    os.remove(folder + '.zip')


if DOWNLOAD_MYFOOD:
    import urllib.request
    try:
        download_zip('myfood', lambda path: urllib.request.urlretrieve(
            MYFOOD_URL, path))
    except Exception as error:   # no Internet: train without it
        print(f'  MyFood FAILED ({error}): fewer chicken breast and steak '
              'crops. On Kaggle, turn Internet on.', flush=True)
if DOWNLOAD_FOODINSSEG:
    try:
        download_zip('foodinsseg', lambda path: load_gdown().download(
            id=FOODINSSEG_ID, output=path, quiet=True))
    except Exception as error:
        # Google Drive refuses a file many people downloaded that day.
        raise RuntimeError(
            f'Could not download FoodInsSeg: {error!r}. Try again later, or set '
            'DOWNLOAD_FOODINSSEG to 0 to train without it.') from error
stage(f'Photos from {INPUT_ROOT} and {EXTRA_ROOT} | results to {OUTPUT_DIR}')

# %% [markdown]
# ## Contract
# Class codes in output order (contract 1.8, §9.1). They must match
# `meat_classes.txt`, which this notebook writes at the end. The meats are
# detector classes (§7.1) and keep its codes.

# %%
CONTRACT_VERSION = '1.8'
CLASSES = ['ga', 'thit_kho', 'thit_nuong', 'heo', 'bo', 'ca', 'tom', 'khac']
OTHER = 'khac'
MEATS = CLASSES[:-1]
CLASS_INDEX = {code: i for i, code in enumerate(CLASSES)}

# VietFood67 class id → name (its data.yaml), as in train_detector.py.
VF_NAMES = [
    'Banh canh', 'Banh chung', 'Banh cuon', 'Banh khot', 'Banh mi',
    'Banh trang', 'Banh trang tron', 'Banh xeo', 'Bo kho', 'Bo la lot',
    'Bong cai', 'Bun', 'Bun bo Hue', 'Bun cha', 'Bun dau', 'Bun mam',
    'Bun rieu', 'Ca', 'Ca chua', 'Ca phao', 'Ca rot', 'Canh', 'Cha',
    'Cha gio', 'Chanh', 'Com', 'Com tam', 'person', 'Cu kieu', 'Cua',
    'Dau hu', 'Dua chua', 'Dua leo', 'Goi cuon', 'Hamburger', 'Heo quay',
    'Hu tieu', 'Kho qua thit', 'Khoai tay chien', 'Lau', 'Long heo', 'Mi',
    'Muc', 'Nam', 'Oc', 'Ot chuong', 'Pho', 'Pho mai', 'Rau', 'Salad',
    'Thit bo', 'Thit ga', 'Thit heo', 'Thit kho', 'Thit nuong', 'Tom',
    'Trung', 'Xoi', 'Banh beo', 'Cao lau', 'Mi Quang',
    'Com chien Duong Chau', 'Bun cha ca', 'Com chien ga', 'Chao long',
    'Nom hoa chuoi', 'Nui xao bo', 'Sup cua',
]
assert len(VF_NAMES) == 68
VF_MEAT = {
    'Thit ga': 'ga', 'Thit kho': 'thit_kho', 'Thit nuong': 'thit_nuong',
    'Thit heo': 'heo', 'Heo quay': 'heo', 'Thit bo': 'bo', 'Ca': 'ca',
    'Tom': 'tom',
}
# Boxes of a food that is plainly not one of the meats: `khac` crops. Whole
# dishes (Pho, Com tam…), crab, snails, offal and sausage are left out, as
# they hold or look like meat.
VF_OTHER = {
    'Com', 'Bun', 'Mi', 'Banh mi', 'Trung', 'Dau hu', 'Rau', 'Bong cai',
    'Dua leo', 'Ca chua', 'Dua chua', 'Khoai tay chien', 'Canh', 'Muc',
    'Ca rot', 'Chanh', 'Nam', 'Ot chuong', 'Ca phao', 'Banh trang',
}
assert set(VF_MEAT) | VF_OTHER <= set(VF_NAMES)
# MyFood: mask value → class (5 chicken breast, 10 steak; 4 and 9 eggs,
# 6 rice, 7 salad, 8 spaghetti as other food).
MYFOOD_CLASS = {5: 'ga', 10: 'bo', 4: OTHER, 6: OTHER, 7: OTHER, 8: OTHER,
                9: OTHER}
# FoodInsSeg: category name → class, as the detector maps them.
FIS_MEAT = {'pork': 'heo', 'chicken duck': 'ga', 'steak': 'bo', 'fish': 'ca',
            'shrimp': 'tom'}
# Foods on a plate that are plainly not meat: `khac` crops. Other meats
# (fried meat, sausage, lamb, crab), sauce and mixed foods are left out.
FIS_OTHER = {
    'rice', 'egg', 'tofu', 'french fries', 'cucumber', 'tomato', 'lettuce',
    'broccoli', 'cabbage', 'bean sprouts', 'rape', 'corn', 'carrot',
    'potato', 'green beans', 'French beans', 'asparagus', 'cauliflower',
    'eggplant', 'pumpkin', 'white radish', 'okra', 'snow peas', 'pepper',
    'onion', 'white button mushroom', 'shiitake', 'soy', 'red beans',
}
# The photos train_detector.py leaves out (FIS_UNSURE there): only their
# meat boxes are used here, as their other foods may hide unlabelled meat.
FIS_UNSURE = {
    'bread', 'noodles', 'pasta', 'soup', 'fried meat', 'sausage',
    'wonton dumplings', 'hanamaki baozi', 'hamburg', 'salad',
    'other ingredients',
}

# %% [markdown]
# ## Find the boxes
# Each box becomes one item (photo, split, class, box); the photos are
# shrunk once afterwards, only those with a box used.

# %%
import json
import random
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image, ImageOps

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
SPLITS = {'train': 'train', 'training': 'train', 'valid': 'val', 'val': 'val',
          'validation': 'val', 'test': 'test', 'testing': 'test'}
random.seed(SEED)
skipped = Counter()


def corners(cx, cy, w, h):
    return (max(0.0, cx - w / 2), max(0.0, cy - h / 2), min(1.0, cx + w / 2),
            min(1.0, cy + h / 2))


def big_enough(box):
    return box[2] - box[0] >= MIN_BOX and box[3] - box[1] >= MIN_BOX


def join_pieces(boxes):
    """(code, l, t, r, b) boxes with those of one code that overlap or lie
    within JOIN_GAP of each other replaced by one box around them."""
    group = list(range(len(boxes)))

    def root(i):
        while group[i] != i:
            group[i] = group[group[i]]
            i = group[i]
        return i

    for i, a in enumerate(boxes):
        for j in range(i + 1, len(boxes)):
            b = boxes[j]
            if (a[0] == b[0] and a[1] - JOIN_GAP <= b[3] and
                    b[1] - JOIN_GAP <= a[3] and a[2] - JOIN_GAP <= b[4] and
                    b[2] - JOIN_GAP <= a[4]):
                group[root(i)] = root(j)
    out = {}
    for i, (c, left, top, right, bottom) in enumerate(boxes):
        r = root(i)
        if r in out:
            _, l0, t0, r0, b0 = out[r]
            out[r] = (c, min(l0, left), min(t0, top), max(r0, right),
                      max(b0, bottom))
        else:
            out[r] = (c, left, top, right, bottom)
    return list(out.values())


def split_of(path):
    for part in reversed(path.replace('\\', '/').split('/')):
        if part.lower() in SPLITS:
            return SPLITS[part.lower()]
    return 'train'


def find_roots(top, test):
    found = []
    for folder, dirs, files in os.walk(top, followlinks=True):
        if test(folder, files):
            found.append(folder)
            dirs[:] = []
    return found


def vf67_items(root):
    images = {}
    for folder, _, names in os.walk(os.path.join(root, 'images'),
                                    followlinks=True):
        for name in names:
            stem, ext = os.path.splitext(name)
            if ext.lower() in IMAGE_EXT:
                rel = os.path.relpath(os.path.join(folder, stem),
                                      os.path.join(root, 'images'))
                images.setdefault(rel, os.path.join(folder, name))
    labels = []
    for folder, _, names in os.walk(os.path.join(root, 'labels'),
                                    followlinks=True):
        for name in sorted(names):
            if name.endswith('.txt'):
                path = os.path.join(folder, name)
                rel = os.path.splitext(
                    os.path.relpath(path, os.path.join(root, 'labels')))[0]
                if rel in images:
                    labels.append((path, rel))
    stage(f'VietFood67: {len(images)} images, {len(labels)} label files in '
          f'{root}')

    def read(path):
        boxes = []
        with open(path) as f:
            for line in f:
                parts = line.split()
                if len(parts) < 5 or not parts[0].isdigit():
                    continue
                index = int(parts[0])
                if index >= len(VF_NAMES):
                    continue
                try:
                    box = corners(*(float(p) for p in parts[1:5]))
                except ValueError:
                    continue
                name = VF_NAMES[index]
                code = (VF_MEAT.get(name) or
                        (OTHER if name in VF_OTHER else None))
                if code and big_enough(box):
                    boxes.append((code, *box))
        return boxes

    # Kaggle fetches each file of a dataset the first time it is read, so
    # the 171,619 label files are read 64 at a time.
    items = []
    with ThreadPoolExecutor(64) as pool:
        for (path, rel), boxes in zip(labels, pool.map(
                read, (path for path, _ in labels))):
            for code, *box in boxes:
                items.append(('vf67', images[rel], split_of(rel), code, box))
    return items


def myfood_items(root):
    """One box around each MyFood food: its plates hold one chicken breast
    or steak, and two eggs in one box are still `khac`."""
    items = []
    for split in ('train', 'val', 'test'):
        folder = os.path.join(root, split)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            stem, ext = os.path.splitext(name)
            mask_path = os.path.join(root, f'{split}_ann', stem + '.png')
            if ext.lower() not in IMAGE_EXT or not os.path.exists(mask_path):
                continue
            with Image.open(mask_path) as mask:
                values = np.asarray(mask)
            if values.ndim == 3:   # RGB(A) masks hold the class in red
                values = values[..., 0]
            height, width = values.shape
            for value, code in MYFOOD_CLASS.items():
                rows, cols = np.nonzero(values == value)
                if len(rows) < 0.004 * values.size:   # specks
                    continue
                box = (cols.min() / width, rows.min() / height,
                       (cols.max() + 1) / width, (rows.max() + 1) / height)
                if big_enough(box):
                    items.append(('myfood', os.path.join(folder, name), split,
                                  code, box))
    return items


def overlaps(box, others, limit):
    for o in others:
        left, top = max(box[0], o[0]), max(box[1], o[1])
        right, bottom = min(box[2], o[2]), min(box[3], o[3])
        if right > left and bottom > top and (right - left) * (bottom - top) > (
                limit * (box[2] - box[0]) * (box[3] - box[1])):
            return True
    return False


def foodinsseg_items(root):
    """FoodInsSeg's boxes, and empty patches of its photos. Its test photos
    are halved into val (even ids) and test (odd), as for the detector."""
    items = []
    rng = random.Random(SEED)
    for json_name, folder in (('Train.json', 'train'), ('Test.json', 'test')):
        with open(os.path.join(root, 'annotations', json_name)) as f:
            coco = json.load(f)
        names = {c['id']: c['name'] for c in coco['categories']}
        unknown = (set(FIS_MEAT) | FIS_OTHER | FIS_UNSURE) - set(names.values())
        assert not unknown, f'FoodInsSeg has no category {unknown}'
        per_image = {}
        for a in coco['annotations']:
            per_image.setdefault(a['image_id'], []).append(a)
        for image in coco['images']:
            width, height = image['width'], image['height']
            split = ('train' if folder == 'train' else
                     'val' if image['id'] % 2 == 0 else 'test')
            path = os.path.join(root, 'images', folder, image['file_name'])
            found = per_image.get(image['id'], [])
            # Photos the detector leaves out give meat crops only.
            unsure = any(names[a['category_id']] in FIS_UNSURE for a in found)
            pieces, every = [], []
            for a in found:
                left, top, w, h = a['bbox']
                name = names[a['category_id']]
                box = (left / width, top / height, (left + w) / width,
                       (top + h) / height)
                every.append(box)
                if w > 0 and h > 0 and (name in FIS_MEAT or (
                        name in FIS_OTHER and not unsure)):
                    pieces.append((name, *box))
            # Pieces of one food are joined, as for the detector; eggs, which
            # the detector counts, are not.
            joined = (join_pieces([p for p in pieces if p[0] != 'egg']) +
                      [p for p in pieces if p[0] == 'egg'])
            for name, *box in joined:
                if big_enough(box):
                    items.append(('fis', path, split,
                                  FIS_MEAT.get(name, OTHER), box))
            # One empty patch a photo: plate or table, no food under it.
            for _ in range(10 if not unsure else 0):
                w, h = rng.uniform(0.15, 0.4), rng.uniform(0.15, 0.4)
                left, top = rng.uniform(0, 1 - w), rng.uniform(0, 1 - h)
                box = (left, top, left + w, top + h)
                if every and not overlaps(box, every, 0.1):
                    items.append(('fis_empty', path, split, OTHER, box))
                    break
    return items


items = []
for root in find_roots(INPUT_ROOT, lambda folder, _: (
        os.path.isdir(os.path.join(folder, 'images')) and
        os.path.isdir(os.path.join(folder, 'labels')))):
    items += vf67_items(root)
for root in find_roots(EXTRA_ROOT, lambda folder, files:
                       os.path.isdir(os.path.join(folder, 'train_ann'))):
    items += myfood_items(root)
for root in find_roots(EXTRA_ROOT, lambda folder, files: os.path.exists(
        os.path.join(folder, 'annotations', 'Train.json'))):
    items += foodinsseg_items(root)
if not any(code in MEATS for *_, code, _ in items):
    raise RuntimeError(f'No meat boxes under {INPUT_ROOT} or {EXTRA_ROOT}: add '
                       f'{VF67_REF}, or let FoodInsSeg download.')

# Per split: every meat box, and `khac` crops up to OTHER_SHARE of them,
# BACKGROUND_SHARE of those empty patches.
chosen = []
for split in ('train', 'val', 'test'):
    here = [i for i in items if i[2] == split]
    meat = [i for i in here if i[3] in MEATS]
    food = [i for i in here if i[3] == OTHER and i[0] != 'fis_empty']
    empty = [i for i in here if i[0] == 'fis_empty']
    random.shuffle(food)
    random.shuffle(empty)
    others = int(OTHER_SHARE * len(meat))
    n_empty = min(len(empty), int(BACKGROUND_SHARE * others))
    chosen += meat + food[:others - n_empty] + empty[:n_empty]
if QUICK_TEST:
    random.shuffle(chosen)
    chosen = chosen[:400]
    # Every split needs crops, even in a quick test.
    for i, split in enumerate(['val', 'test']):
        if not any(item[2] == split for item in chosen):
            chosen[i] = (*chosen[i][:2], split, *chosen[i][3:])

# %% [markdown]
# ## Shrink the photos
# Each photo with a chosen box is turned upright and shrunk once to
# PHOTO_SIDE, the size the app cuts from, in parallel (Kaggle reads its
# input lazily, file by file).

# %%
SMALL_DIR = os.path.join(WORK_DIR, 'small')
os.makedirs(SMALL_DIR, exist_ok=True)
photos = sorted({item[1] for item in chosen})
small_of = {path: os.path.join(SMALL_DIR, f'{i:06d}.jpg')
            for i, path in enumerate(photos)}


def shrink(path):
    target = small_of[path]
    if os.path.exists(target):
        return True
    try:
        with Image.open(path) as im:
            im = ImageOps.exif_transpose(im).convert('RGB')
            scale = PHOTO_SIDE / max(im.size)
            # The size the app fits the photo into for the detector (it
            # resizes without PIL's smoothing).
            size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
            im.resize(size, Image.BILINEAR).save(target + '.part.jpg', quality=92)
        os.replace(target + '.part.jpg', target)
        return True
    except Exception:
        return False


stage(f'Shrinking {len(photos)} photos to {PHOTO_SIDE} px ...')
with ThreadPoolExecutor(32) as pool:
    readable = dict(zip(photos, pool.map(shrink, photos)))
skipped['unreadable photo'] = sum(not ok for ok in readable.values())
data = {'train': [], 'val': [], 'test': []}
for source, path, split, code, box in chosen:
    if readable[path]:
        data[split].append({'file': small_of[path], 'source': source,
                            'label': CLASS_INDEX[code], 'box': box})
counts = {split: Counter(CLASSES[s['label']] for s in rows)
          for split, rows in data.items()}
stage(f'Crops: { {k: len(v) for k, v in data.items()} } | skipped: '
      f'{dict(skipped)}')
print(f'{"class":12} {"train":>7} {"val":>6} {"test":>6}')
for code in CLASSES:
    print(f'{code:12} ' + ' '.join(f'{counts[s][code]:>{w}}' for s, w in
                                   (('train', 7), ('val', 6), ('test', 6))))
print('Sources:', dict(Counter(s['source'] for rows in data.values()
                               for s in rows)))

# Balance train: small classes repeated, large ones cut.
train = []
for label in range(len(CLASSES)):
    rows = [s for s in data['train'] if s['label'] == label]
    random.shuffle(rows)
    rows = rows[:MAX_PER_CLASS]
    if rows and len(rows) < MIN_PER_CLASS:
        rows = (rows * (MIN_PER_CLASS // len(rows) + 1))[:MIN_PER_CLASS]
    train += rows
random.shuffle(train)
val, test = data['val'], data['test']
stage(f'Train after balancing: {len(train)} crops')

# %% [markdown]
# ## Input pipeline
# Matches the app (contract §9.2): the box grown by CROP_PAD on each side,
# cut to the photo, resized to IMG×IMG by bilinear sampling
# (`tf.image.crop_and_resize`), raw RGB 0–255 (the model normalizes
# inside). Training also moves and resizes the box a little, flips it and
# changes the colours slightly.

# %%
import tensorflow as tf
from tensorflow import keras

tf.random.set_seed(SEED)
N = len(CLASSES)
if MIXED_PRECISION == 'always' or (
        MIXED_PRECISION == 'gpu' and tf.config.list_physical_devices('GPU')):
    keras.mixed_precision.set_global_policy('mixed_float16')
print('Precision:', keras.mixed_precision.global_policy().name,
      '| GPUs:', len(tf.config.list_physical_devices('GPU')))


def padded(box):
    """The crop the app cuts for [box] (l, t, r, b as shares of the photo)."""
    left, top, right, bottom = tf.unstack(box)
    w, h = right - left, bottom - top
    return tf.stack([tf.maximum(0.0, top - CROP_PAD * h),
                     tf.maximum(0.0, left - CROP_PAD * w),
                     tf.minimum(1.0, bottom + CROP_PAD * h),
                     tf.minimum(1.0, right + CROP_PAD * w)])


def jittered(box):
    left, top, right, bottom = tf.unstack(box)
    w, h = right - left, bottom - top
    cx = (left + right) / 2 + tf.random.uniform([], -BOX_SHIFT, BOX_SHIFT) * w
    cy = (top + bottom) / 2 + tf.random.uniform([], -BOX_SHIFT, BOX_SHIFT) * h
    w *= tf.random.uniform([], 1 - BOX_SCALE, 1 + BOX_SCALE)
    h *= tf.random.uniform([], 1 - BOX_SCALE, 1 + BOX_SCALE)
    return tf.stack([tf.maximum(0.0, cx - w / 2), tf.maximum(0.0, cy - h / 2),
                     tf.minimum(1.0, cx + w / 2), tf.minimum(1.0, cy + h / 2)])


def make_dataset(rows, training):
    ds = tf.data.Dataset.from_tensor_slices((
        [s['file'] for s in rows],
        np.array([s['box'] for s in rows], np.float32).reshape(-1, 4),
        np.array([s['label'] for s in rows], np.int32)))
    if training and rows:
        ds = ds.shuffle(len(rows), seed=SEED, reshuffle_each_iteration=True)

    def load(path, box, label):
        image = tf.io.decode_jpeg(tf.io.read_file(path), channels=3)
        image = tf.cast(image, tf.float32)
        if training:
            box = jittered(box)
        crop = tf.image.crop_and_resize(image[None], padded(box)[None], [0],
                                        [IMG, IMG], method='bilinear')[0]
        if training:
            crop = tf.image.random_flip_left_right(crop)
            crop = tf.image.random_brightness(crop, 20.0)
            crop = tf.image.random_contrast(crop, 0.85, 1.15)
            crop = tf.image.random_saturation(crop, 0.85, 1.15)
        crop = tf.clip_by_value(crop, 0.0, 255.0)
        return crop, tf.one_hot(label, N)

    return (ds.map(load, num_parallel_calls=tf.data.AUTOTUNE)
            .batch(BATCH)
            .prefetch(tf.data.AUTOTUNE))


train_ds = make_dataset(train, True)
val_ds = make_dataset(val, False)
test_ds = make_dataset(test, False)

# %% [markdown]
# ## Model and training
# The backbone first stays frozen while the new head learns, then all of it
# is fine-tuned with a falling learning rate. The epoch with the best val
# accuracy is kept.

# %%
def build_model():
    common = dict(input_shape=(IMG, IMG, 3), include_top=False,
                  weights=None if WEIGHTS == 'none' else WEIGHTS,
                  include_preprocessing=True)   # takes raw RGB 0–255
    if BACKBONE == 'mobilenetv3large':
        base = keras.applications.MobileNetV3Large(**common)
    elif BACKBONE == 'mobilenetv3small':
        base = keras.applications.MobileNetV3Small(**common)
    else:
        raise ValueError(BACKBONE)
    inputs = keras.Input((IMG, IMG, 3), name='image')
    # Pretrained batch-norm statistics stay fixed while fine-tuning.
    x = base(inputs, training=False)
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.3)(x)
    # float32 output, also under mixed precision, for a stable loss.
    out = keras.layers.Dense(N, activation='softmax', name='meat',
                             dtype='float32')(x)
    return keras.Model(inputs, out), base


model, base = build_model()
BEST = os.path.join(OUTPUT_DIR, 'best.keras')
history = {}
started = time.time()


def fit(epochs, learning_rate, phase):
    steps = max(1, -(-len(train) // BATCH)) * epochs
    schedule = (learning_rate if phase == 'head' else
                keras.optimizers.schedules.CosineDecay(learning_rate, steps))
    model.compile(optimizer=keras.optimizers.Adam(schedule),
                  loss=keras.losses.CategoricalCrossentropy(label_smoothing=0.1),
                  metrics=['accuracy'])
    stage(f'{phase}: {epochs} epochs')
    result = model.fit(train_ds, validation_data=val_ds, epochs=epochs,
                       verbose=2, callbacks=[keras.callbacks.ModelCheckpoint(
                           BEST, monitor='val_accuracy', save_best_only=True,
                           initial_value_threshold=history.get('best'))])
    history[phase] = {k: [round(float(v), 4) for v in values]
                      for k, values in result.history.items()}
    history['best'] = max([history.get('best') or 0.0] +
                          history[phase]['val_accuracy'])


base.trainable = False
fit(EPOCHS_HEAD, 1e-3, 'head')
base.trainable = True
fit(EPOCHS_FINE, LEARNING_RATE, 'fine')
model = keras.models.load_model(BEST)
train_minutes = (time.time() - started) / 60
stage(f'Training done in {train_minutes:.0f} minutes, best val accuracy '
      f'{history["best"]:.3f}')

# %% [markdown]
# ## Test
# Accuracy on the test boxes, per class, and how often the classifier
# names another meat when it is sure (what makes the app rename a box).

# %%
def predict(ds):
    probs, truth = [], []
    for images, labels in ds:
        probs.append(model(images, training=False).numpy())
        truth.append(labels.numpy().argmax(-1))
    if not probs:
        return np.zeros((0, N)), np.zeros(0, int)
    return np.concatenate(probs), np.concatenate(truth)


results = {'backbone': BACKBONE, 'img': IMG, 'crop_pad': CROP_PAD,
           'history': history, 'crops': {k: len(v) for k, v in data.items()}}
for split, ds in (('val', val_ds), ('test', test_ds)):
    probs, truth = predict(ds)
    guess = probs.argmax(-1)
    results[f'{split}_accuracy'] = round(float((guess == truth).mean()), 4) if len(truth) else None
    confusion = np.zeros((N, N), int)
    for t, g in zip(truth, guess):
        confusion[t, g] += 1
    results[f'{split}_confusion'] = confusion.tolist()
    # For each confidence, the share of sure answers that are right.
    sure = {}
    for threshold in (0.5, 0.6, 0.7, 0.8, 0.9):
        mask = probs.max(-1) >= threshold
        sure[threshold] = (round(float(mask.mean()), 3) if len(truth) else None,
                           round(float((guess[mask] == truth[mask]).mean()), 3)
                           if mask.any() else None)
    results[f'{split}_sure'] = sure
print('Test accuracy:', results['test_accuracy'], '| val:', results['val_accuracy'])
print('Test confusion (rows: truth, columns: answer):')
print(' ' * 11 + ''.join(f'{c[:6]:>7}' for c in CLASSES))
for code, row in zip(CLASSES, results['test_confusion']):
    print(f'{code:11}' + ''.join(f'{v:>7}' for v in row))
print('Val, by confidence (share of boxes, share right):', results['val_sure'])
per_class = {code: round(row[i] / max(1, sum(row)), 3)
             for i, (code, row) in enumerate(zip(CLASSES,
                                                 results['test_confusion']))}

# %% [markdown]
# ## Export the files the app reads
# float16 TFLite, input `[1, IMG, IMG, 3]` raw RGB 0–255, output the 8
# class probabilities; checked against Keras before writing.

# %%
from datetime import date


def float32_config(config):
    """[config] with every mixed-precision layer turned float32."""
    if isinstance(config, dict):
        if config.get('config', {}).get('name') == 'mixed_float16':
            config = {**config, 'config': {**config['config'], 'name': 'float32'}}
        return {k: float32_config(v) for k, v in config.items()}
    if isinstance(config, list):
        return [float32_config(v) for v in config]
    return config


keras.mixed_precision.set_global_policy('float32')
export_model = keras.Model.from_config(float32_config(model.get_config()))
export_model.set_weights(model.get_weights())
sample = next(iter(test_ds if test else val_ds))[0][:4]
assert np.abs(export_model(sample, training=False).numpy() -
              model(sample, training=False).numpy()).max() < 0.02, \
    'The export copy differs from the trained model'
stage('converting to float16 TFLite')
converter = tf.lite.TFLiteConverter.from_keras_model(export_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite = converter.convert()
with open(os.path.join(OUTPUT_DIR, 'meat_classifier.tflite'), 'wb') as f:
    f.write(tflite)
interpreter = tf.lite.Interpreter(model_content=tflite)
interpreter.allocate_tensors()
(inp,), (out,) = interpreter.get_input_details(), interpreter.get_output_details()
assert list(inp['shape']) == [1, IMG, IMG, 3] and inp['dtype'] == np.float32
assert list(out['shape']) == [1, N] and out['dtype'] == np.float32
for image in sample.numpy():
    interpreter.set_tensor(inp['index'], image[None])
    interpreter.invoke()
    assert np.abs(interpreter.get_tensor(out['index'])[0] -
                  export_model(image[None], training=False).numpy()[0]).max() < 0.02, \
        'TFLite differs from Keras'
for _ in range(5):
    interpreter.invoke()
timed = time.time()
for _ in range(20):
    interpreter.invoke()
results['cpu_ms'] = round((time.time() - timed) / 20 * 1000, 1)
results['tflite_mb'] = round(len(tflite) / 1e6, 2)
with open(os.path.join(OUTPUT_DIR, 'meat_classes.txt'), 'w') as f:
    f.write('\n'.join(CLASSES) + '\n')
with open(os.path.join(OUTPUT_DIR, 'results.json'), 'w') as f:
    json.dump(results, f, indent=2)

sources = Counter(s['source'] for rows in data.values() for s in rows)
# The override thresholds are only a start: tool/train/eval_meat_classifier.py
# tunes them on the detector's own boxes.
card = f"""# Meat classifier card

contract_version: {CONTRACT_VERSION}
crop_pad: {CROP_PAD:.2f}
threshold_rename: 0.70

- Trained: {date.today().isoformat()}, {BACKBONE} at {IMG}×{IMG}{' (QUICK TEST, DO NOT SHIP)' if QUICK_TEST else ''}
- Crops: {len(data['train'])} train ({len(train)} after balancing) / {len(val)} val / {len(test)} test, from {', '.join(f'{k} {v}' for k, v in sources.most_common())}
- Photos shrunk to {PHOTO_SIDE} px, box grown by {CROP_PAD:.0%} a side
- Test accuracy on the boxes: {results['test_accuracy']}, val {results['val_accuracy']}
- File: meat_classifier.tflite, float16 weights, {results['tflite_mb']} MB, {results['cpu_ms']} ms a box on the training machine's CPU
- Thresholds: the default above; tune them with tool/train/eval_meat_classifier.py on the detector's own boxes

| class | test boxes | right |
|---|---|---|
""" + ''.join(f'| {code} | {counts["test"][code]} | {per_class[code]} |\n'
              for code in CLASSES)
with open(os.path.join(OUTPUT_DIR, 'MEAT_CARD.md'), 'w', encoding='utf-8') as f:
    f.write(card)
print(card)
stage('done')
print('Download from Output:', sorted(os.listdir(OUTPUT_DIR)))
if ON_COLAB:
    drive.flush_and_unmount()
    print('All files are on Google Drive.')
