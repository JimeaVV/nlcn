# %% [markdown]
# # MacroRunner – train the food recognition model
#
# Trains the two-output model described in `docs/MODEL_CONTRACT.md`
# (contract 1.2): a softmax over 40 dishes and an independent probability per
# component (25). The result is the four files the app reads from
# `assets/models/`.
#
# **On Kaggle**
# 1. *Add data*: VinaFood21, 30VNFoods (vietnamese-foods), 20FoodVN,
#    VietFood67 (vietfood68), and the team's own photos if any.
# 2. *Settings*: Accelerator **GPU T4 x2**, Internet **on**.
# 3. Run once with `QUICK_TEST = True` (a few minutes) to check everything.
# 4. Set `QUICK_TEST = False`, then **Save Version → Save & Run All**. It keeps
#    running with the browser closed; take the files from the *Output* tab.
#
# The four public datasets are merged into one training set. Class folders are
# renamed to the app's codes; classes the app does not have are skipped.
# VietFood67 has bounding boxes, which also give component labels: a plate
# with boxes for rice, braised pork and vegetables but no dish box is a
# *cơm phần*.

# %%
import os

QUICK_TEST = True          # True: a few hundred images, 1 epoch per phase.
EXPERIMENT = 'finetune'    # 'scratch' | 'linear' | 'finetune' (report §3)
BACKBONE = 'mobilenetv3'   # 'mobilenetv3' | 'efficientnetv2b0'

INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/kaggle/working')
SEED = 42
IMG = 224
BATCH = 16 if QUICK_TEST else 64
EPOCHS_HEAD = 1 if QUICK_TEST else 5    # backbone frozen
EPOCHS_FINE = 1 if QUICK_TEST else 15   # top of the backbone unfrozen
MAX_PER_DISH = 12 if QUICK_TEST else 1500  # caps the largest classes
# Photos of food the app does not know become the extra class "khac", so the
# model can say "not in the app" instead of forcing a close match.
USE_OTHER = True
MAX_OTHER = 24 if QUICK_TEST else 3000
UNFREEZE_FRACTION = 0.4                 # share of backbone layers fine-tuned
# 30VNFoods and VietFood67 have one "Phở" class for both beef and chicken.
# 'skip' leaves those photos out; 'pho_bo' counts them as beef phở.
MIXED_PHO = 'skip'

os.makedirs(OUTPUT_DIR, exist_ok=True)

# %% [markdown]
# ## Contract
# Codes in output order. They must match `dishes.txt` and `components.txt`,
# which this notebook writes at the end.

# %%
CONTRACT_VERSION = '1.3'
DISHES = [
    'com_tam', 'com_phan', 'com_ga', 'com_chien', 'pho_bo', 'pho_ga',
    'bun_bo_hue', 'bun_cha', 'bun_rieu', 'bun_thit_nuong', 'hu_tieu',
    'mi_quang', 'banh_canh', 'bo_kho', 'chao', 'banh_mi', 'banh_cuon',
    'banh_xeo', 'goi_cuon', 'xoi', 'bo_la_lot', 'ha_cao', 'banh_uot',
    'banh_hoi', 'thit_kho_trung', 'banh_can', 'ca_ri', 'bap_nuong',
    'banh_trang_tron', 'hoanh_thanh_nuoc', 'pha_lau', 'tau_hu', 'bot_chien',
    'ga_nuong', 'banh_u', 'banh_tet', 'goi_ga', 'canh_khoai_mo',
    'canh_kho_qua', 'banh_mi_chao', 'banh_chung', 'banh_khot', 'banh_beo',
    'cao_lau', 'bun_dau', 'bun_mam', 'chao_long', 'ca_kho', 'canh_chua',
    'trung_vit_lon', 'che', 'nuoc_mia',
]
OTHER = 'khac'   # last dish output; not an app dish (contract §6)
COMPONENTS = [
    'com', 'bun', 'banh_pho', 'mi', 'banh_mi_o', 'xoi_nep', 'suon_nuong',
    'thit_nuong', 'thit_kho', 'bi', 'cha_trung', 'trung_op_la', 'trung_kho',
    'ga', 'ga_chien', 'bo', 'ca', 'tom', 'dau_hu', 'cha_lua', 'rau_song',
    'rau_nau', 'do_chua', 'dua_leo_ca_chua', 'mo_hanh',
]
assert len(DISHES) == 52 and len(COMPONENTS) == 25
OUTPUTS = DISHES + ([OTHER] if USE_OTHER else [])
DISH_INDEX = {code: i for i, code in enumerate(OUTPUTS)}
COMP_INDEX = {code: i for i, code in enumerate(COMPONENTS)}

# %% [markdown]
# ## Class names → app codes
# Folder names are compared after removing diacritics, case and punctuation,
# so "Bánh Mì", "banh_mi" and "Banh mi" are the same class.

# %%
import re
import unicodedata


def normalize(name):
    name = unicodedata.normalize('NFD', name.replace('đ', 'd').replace('Đ', 'D'))
    name = ''.join(c for c in name if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


# Classification datasets: folder name (normalized) → dish code. A name that
# already is a dish code maps to itself. Anything else is food the app does
# not know and becomes "khac", except the names mapped to None here.
CLASS_ALIASES = {
    # 30VNFoods
    'xoi_xeo': 'xoi',
    'hu_tieu': 'hu_tieu',
    'bun_dau_mam_tom': 'bun_dau',
    'ca_kho_to': 'ca_kho',
    # Beef and chicken phở in one class: an app dish, but which one is unknown.
    'pho': None if MIXED_PHO == 'skip' else MIXED_PHO,
    # 20FoodVN
    'banh_canh_ghe': 'banh_canh',
    'hu_tieu_nam_vang': 'hu_tieu',
    'ca_loc_kho': 'ca_kho',
    'che_thai': 'che',
    'che_buoi': 'che',
}


def dish_for_folder(folder):
    key = normalize(folder)
    if key in CLASS_ALIASES:
        return CLASS_ALIASES[key]
    if key in DISH_INDEX and key != OTHER:
        return key
    return OTHER if USE_OTHER else None


# VietFood67: class id → name (its data.yaml, 68 classes).
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
# Boxes that name the whole dish.
VF_DISH = {
    'Banh canh': 'banh_canh', 'Banh cuon': 'banh_cuon', 'Banh mi': 'banh_mi',
    'Banh trang tron': 'banh_trang_tron', 'Banh xeo': 'banh_xeo',
    'Bo kho': 'bo_kho', 'Bo la lot': 'bo_la_lot', 'Bun bo Hue': 'bun_bo_hue',
    'Bun cha': 'bun_cha', 'Bun rieu': 'bun_rieu', 'Com tam': 'com_tam',
    'Goi cuon': 'goi_cuon', 'Hu tieu': 'hu_tieu', 'Mi Quang': 'mi_quang',
    'Xoi': 'xoi', 'Com chien Duong Chau': 'com_chien',
    'Com chien ga': 'com_chien', 'Banh chung': 'banh_chung',
    'Banh khot': 'banh_khot', 'Banh beo': 'banh_beo', 'Cao lau': 'cao_lau',
    'Bun dau': 'bun_dau', 'Bun mam': 'bun_mam', 'Chao long': 'chao_long',
    'Pho': None if MIXED_PHO == 'skip' else MIXED_PHO,
}
# Whole dishes VietFood67 has but the app does not: photos of them are "khac".
VF_OTHER = {'Lau', 'Bun cha ca', 'Nom hoa chuoi', 'Nui xao bo', 'Sup cua',
            'Hamburger', 'Khoai tay chien', 'Salad'}
# Boxes that name one component without ambiguity.
VF_COMPONENT = {
    'Com': 'com', 'Bun': 'bun', 'Mi': 'mi', 'Ca': 'ca', 'Tom': 'tom',
    'Dau hu': 'dau_hu', 'Thit kho': 'thit_kho', 'Thit nuong': 'thit_nuong',
    'Thit bo': 'bo', 'Thit ga': 'ga', 'Dua chua': 'do_chua',
    'Dua leo': 'dua_leo_ca_chua', 'Ca chua': 'dua_leo_ca_chua',
    'Pho': 'banh_pho', 'Xoi': 'xoi_nep',
}
# Components VietFood67 can confirm as present or absent. The rest stay
# unknown (masked) for its photos, so their absence is not learned as "no".
VF_OBSERVED = set(VF_COMPONENT.values()) | {'banh_mi_o'}
PROTEIN_BOXES = {'Ca', 'Tom', 'Dau hu', 'Thit kho', 'Thit nuong', 'Thit bo',
                 'Thit ga', 'Trung', 'Thit heo', 'Heo quay', 'Muc', 'Oc',
                 'Cua', 'Long heo', 'Cha'}


def vf_resolve(dish, names):
    """Components (present, observed) for a VietFood67 photo of [dish]."""
    present, observed = set(), set(VF_OBSERVED)
    for name in names:
        if name in VF_COMPONENT:
            present.add(VF_COMPONENT[name])
    if 'Banh mi' in names and dish != 'banh_mi':
        present.add('banh_mi_o')
    # Classes whose component depends on the dish they sit in.
    if 'Trung' in names:
        code = 'trung_op_la' if dish in {'com_tam', 'banh_mi', 'com_chien',
                                         'banh_mi_chao'} else 'trung_kho'
        present.add(code)
        observed.add(code)
    if 'Cha' in names and dish in {'com_tam', 'banh_mi', 'banh_cuon',
                                   'bun_bo_hue', 'banh_canh'}:
        code = 'cha_trung' if dish == 'com_tam' else 'cha_lua'
        present.add(code)
        observed.add(code)
    if 'Rau' in names:
        code = 'rau_nau' if dish == 'com_phan' else 'rau_song'
        present.add(code)
        observed.add(code)
    return present, observed

# %% [markdown]
# ## Collect every photo

# %%
import csv
import hashlib
import random

from PIL import Image
from collections import Counter, defaultdict

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
# TensorFlow cannot decode WebP, so those photos are converted to JPEG here.
CONVERTED_DIR = os.environ.get('CONVERTED_DIR', '/tmp/converted')
# Folder names that hold photos but say nothing about the dish.
GENERIC_FOLDERS = {'images', 'image', 'imgs', 'img', 'photos', 'pictures',
                   'data', 'dataset', 'train', 'training', 'test', 'testing',
                   'val', 'valid', 'validation'}


def class_folder(folder):
    """The nearest folder name above the photos that is not generic, e.g.
    'goi_cuon' for 20FoodVN/goi_cuon/images/1.jpg."""
    for name in reversed(os.path.relpath(folder, INPUT_ROOT).split(os.sep)):
        if normalize(name) not in GENERIC_FOLDERS:
            return name
    return os.path.basename(folder)


def readable(path):
    """[path], or a JPEG copy of it when TensorFlow cannot read the format."""
    if not path.lower().endswith('.webp'):
        return path
    os.makedirs(CONVERTED_DIR, exist_ok=True)
    digest = hashlib.md5(path.encode('utf-8')).hexdigest()
    target = os.path.join(CONVERTED_DIR, f'{digest}.jpg')
    if not os.path.exists(target):
        try:
            with Image.open(path) as im:
                im.convert('RGB').save(target, quality=92)
        except Exception:
            return None
    return target
random.seed(SEED)
samples = []   # dicts: path, dish, present (set), observed (set), source
skipped = Counter()


def add(path, dish, source, present=(), observed=()):
    path = readable(path)
    if path is None:
        skipped['unreadable'] += 1
        return
    samples.append({'path': path, 'dish': dish, 'source': source,
                    'present': set(present), 'observed': set(observed)})


def is_detection_root(folder):
    return (os.path.isdir(os.path.join(folder, 'images')) and
            os.path.isdir(os.path.join(folder, 'labels')))


def load_vietfood67(root, source):
    label_paths = sorted(
        os.path.join(folder, name)
        for folder, _, names in os.walk(os.path.join(root, 'labels'),
                                        followlinks=True)
        for name in names if name.endswith('.txt'))
    for label_path in label_paths:
        rel = os.path.relpath(label_path, os.path.join(root, 'labels'))
        stem = os.path.splitext(os.path.join(root, 'images', rel))[0]
        image = next((stem + ext for ext in ('.jpg', '.jpeg', '.png', '.JPG')
                      if os.path.exists(stem + ext)), None)
        if image is None:
            skipped['vf67: no image'] += 1
            continue
        names = set()
        with open(label_path) as f:
            for line in f:
                parts = line.split()
                if parts and parts[0].isdigit() and int(parts[0]) < len(VF_NAMES):
                    names.add(VF_NAMES[int(parts[0])])
        dishes = {VF_DISH[n] for n in names if n in VF_DISH} - {None}
        if len(dishes) > 1:
            skipped['vf67: several dishes'] += 1
            continue
        if dishes:
            dish = dishes.pop()
        elif 'Com' in names and names & PROTEIN_BOXES:
            dish = 'com_phan'   # rice with mains and no dish box
        elif USE_OTHER and names & VF_OTHER:
            dish = OTHER        # a dish the app does not have
        else:
            skipped['vf67: no app dish'] += 1
            continue
        present, observed = vf_resolve(dish, names)
        add(image, dish, source, present, observed)


def load_team_labels(path, source):
    """The team's own photos: labels.csv as in contract §5."""
    folder = os.path.dirname(path)
    with open(path, encoding='utf-8') as f:
        for row in csv.DictReader(f):
            dish = row['dish'].strip()
            if dish not in DISH_INDEX:
                skipped['team: unknown dish'] += 1
                continue
            parts = {c for c in row.get('components', '').split('|') if c}
            unknown = parts - set(COMP_INDEX)
            if unknown:
                skipped['team: unknown component'] += 1
                continue
            image = os.path.join(folder, 'images', row['file'])
            # Every component was checked by a person, so all are observed.
            add(image, dish, source, parts, COMPONENTS)


def source_name(path):
    """The dataset a path belongs to. Kaggle mounts a dataset either at
    /kaggle/input/<name> or at /kaggle/input/datasets/<owner>/<name>."""
    parts = os.path.relpath(path, INPUT_ROOT).split(os.sep)
    if parts[0] == 'datasets' and len(parts) > 2:
        return parts[2]
    return parts[0]


# Each folder is handled by the first rule that matches: the team's
# labels.csv, a detection dataset (images/ + labels/), or class folders.
handled = []   # roots already loaded, whose subfolders are skipped below
# Kaggle may mount datasets as symlinks, which os.walk skips by default.
for folder, dirs, files in os.walk(INPUT_ROOT, followlinks=True):
    dirs.sort()
    if any(folder == root or folder.startswith(root + os.sep) for root in handled):
        dirs[:] = []
        continue
    if 'labels.csv' in files:
        load_team_labels(os.path.join(folder, 'labels.csv'), source_name(folder))
        handled.append(folder)
        dirs[:] = []
    elif is_detection_root(folder):
        load_vietfood67(folder, source_name(folder))
        handled.append(folder)
        dirs[:] = []
    else:
        images = [f for f in files if os.path.splitext(f)[1].lower() in IMAGE_EXT]
        if not images:
            continue
        name = class_folder(folder)
        dish = dish_for_folder(name)
        source = source_name(folder)
        if dish is None:
            skipped[f'{source}: {name}'] += len(images)
            continue
        for name in sorted(images):
            add(os.path.join(folder, name), dish, source)

def show_tree(root, max_depth=4, max_dirs=8):
    """Prints the folder layout, to see how a dataset is organised."""
    base = root.rstrip(os.sep).count(os.sep)
    for folder, dirs, files in os.walk(root, followlinks=True):
        depth = folder.count(os.sep) - base
        if depth > max_depth:
            dirs[:] = []
            continue
        print('  ' * depth + os.path.basename(folder) + f'/  ({len(files)} files)')
        dirs[:] = sorted(dirs)[:max_dirs]


if not samples:
    show_tree(INPUT_ROOT)
    raise RuntimeError(
        f'No photos found under {INPUT_ROOT}. If the datasets were still being '
        'attached, wait until all of them show in the Input panel and run '
        'again; otherwise send the folder tree above so the class names can '
        'be mapped.')

per_dish = Counter(s['dish'] for s in samples)
print(f'{len(samples)} photos from', dict(Counter(s['source'] for s in samples)))
print('Dishes without photos (shoot these):',
      [d for d in DISHES if per_dish[d] == 0])
print(f'"{OTHER}" (food the app does not know):', per_dish[OTHER])
print('Fewest photos:', sorted(per_dish.items(), key=lambda kv: kv[1])[:8])
print('Skipped:', skipped.most_common(12))

# %% [markdown]
# ## Remove duplicates, cap large classes, split 70/15/15 per dish
# The same photo often appears in several public datasets; a copy in train
# and another in test would inflate the test score. Duplicates are found with
# an 8×8 average hash.

# %%
import numpy as np
from PIL import Image


def average_hash(path):
    try:
        with Image.open(path) as im:
            small = im.convert('L').resize((8, 8), Image.BILINEAR)
            pixels = np.asarray(small, dtype=np.float32).flatten().tolist()
    except Exception:
        return None
    mean = sum(pixels) / len(pixels)
    return sum(1 << i for i, p in enumerate(pixels) if p > mean)


# Sorted first, so every run (and every teammate) gets the same split.
samples.sort(key=lambda s: s['path'])
by_dish = defaultdict(list)
seen = {}
for s in samples:
    h = average_hash(s['path'])
    if h is None:
        skipped['unreadable'] += 1
        continue
    if h in seen:
        skipped['duplicate'] += 1
        continue
    seen[h] = s['path']
    by_dish[s['dish']].append(s)

train, val, test = [], [], []
for dish, items in sorted(by_dish.items()):
    random.Random(f'{SEED}-{dish}').shuffle(items)
    items = items[:MAX_OTHER if dish == OTHER else MAX_PER_DISH]
    n_test = max(1, round(len(items) * 0.15)) if len(items) >= 3 else 0
    n_val = max(1, round(len(items) * 0.15)) if len(items) >= 3 else 0
    test += items[:n_test]
    val += items[n_test:n_test + n_val]
    train += items[n_test + n_val:]
print(f'train {len(train)}, val {len(val)}, test {len(test)}; '
      f'duplicates dropped {skipped["duplicate"]}')
with open(os.path.join(OUTPUT_DIR, 'splits.csv'), 'w', newline='',
          encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['file', 'split', 'dish', 'source'])
    for split, items in (('train', train), ('val', val), ('test', test)):
        for s in items:
            writer.writerow([s['path'], split, s['dish'], s['source']])

# %% [markdown]
# ## Input pipeline
# Matches the app: centre square, resized to 224×224, raw RGB 0–255
# (the model normalizes inside). Training adds random crops, flips and light
# colour changes.

# %%
import numpy as np
import tensorflow as tf
from tensorflow import keras

tf.random.set_seed(SEED)
N_DISH, N_COMP = len(OUTPUTS), len(COMPONENTS)


def targets(s):
    labels = np.zeros(N_COMP, np.float32)
    mask = np.zeros(N_COMP, np.float32)
    for c in s['present']:
        labels[COMP_INDEX[c]] = 1
    for c in s['observed']:
        mask[COMP_INDEX[c]] = 1
    return DISH_INDEX[s['dish']], np.concatenate([labels, mask])


def make_dataset(items, training):
    paths = [s['path'] for s in items]
    dish, comp = zip(*(targets(s) for s in items)) if items else ((), ())
    ds = tf.data.Dataset.from_tensor_slices(
        (paths, np.array(dish, np.int32), np.array(comp, np.float32)))
    if training and items:
        ds = ds.shuffle(len(items), seed=SEED, reshuffle_each_iteration=True)

    def load(path, dish, comp):
        image = tf.io.decode_image(tf.io.read_file(path), channels=3,
                                   expand_animations=False)
        image = tf.cast(image, tf.float32)
        h, w = tf.shape(image)[0], tf.shape(image)[1]
        side = tf.minimum(h, w)
        if training:
            # A random square covering 60–100% of the short side.
            side = tf.cast(tf.cast(side, tf.float32) *
                           tf.random.uniform([], 0.6, 1.0), tf.int32)
            image = tf.image.random_crop(image, [side, side, 3])
            image = tf.image.random_flip_left_right(image)
            image = tf.image.random_brightness(image, 20.0)
            image = tf.image.random_contrast(image, 0.85, 1.15)
        else:
            image = tf.image.crop_to_bounding_box(
                image, (h - side) // 2, (w - side) // 2, side, side)
        image = tf.image.resize(image, [IMG, IMG], method='bilinear')
        image = tf.clip_by_value(image, 0.0, 255.0)
        return image, {'dish': dish, 'components': comp}

    return (ds.map(load, num_parallel_calls=tf.data.AUTOTUNE)
            .ignore_errors()
            .batch(BATCH)
            .prefetch(tf.data.AUTOTUNE))


train_ds = make_dataset(train, True)
val_ds = make_dataset(val, False)
test_ds = make_dataset(test, False)

# %% [markdown]
# ## Model: one backbone, two outputs

# %%
def build_model():
    weights = None if EXPERIMENT == 'scratch' else 'imagenet'
    common = dict(input_shape=(IMG, IMG, 3), include_top=False,
                  weights=weights, include_preprocessing=True)
    if BACKBONE == 'mobilenetv3':
        base = keras.applications.MobileNetV3Large(**common)
    elif BACKBONE == 'efficientnetv2b0':
        base = keras.applications.EfficientNetV2B0(**common)
    else:
        raise ValueError(BACKBONE)
    inputs = keras.Input((IMG, IMG, 3), name='image')  # raw RGB 0–255
    # Pretrained batch-norm statistics stay fixed while fine-tuning.
    x = base(inputs, training=EXPERIMENT == 'scratch')
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.2)(x)
    dish = keras.layers.Dense(N_DISH, activation='softmax', name='dish')(x)
    comp = keras.layers.Dense(N_COMP, activation='sigmoid', name='components')(x)
    return keras.Model(inputs, {'dish': dish, 'components': comp}), base


def masked_bce(y_true, y_pred):
    """Binary cross-entropy over the components a photo's labels cover."""
    labels, mask = y_true[:, :N_COMP], y_true[:, N_COMP:]
    bce = keras.backend.binary_crossentropy(labels, y_pred)
    return tf.reduce_sum(bce * mask, axis=-1) / tf.maximum(
        tf.reduce_sum(mask, axis=-1), 1.0)


model, base = build_model()


def compile_model(learning_rate):
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate),
        loss={'dish': 'sparse_categorical_crossentropy',
              'components': masked_bce},
        metrics={'dish': ['accuracy']},
    )


def callbacks(phase):
    return [
        keras.callbacks.ModelCheckpoint(
            os.path.join(OUTPUT_DIR, 'checkpoint.keras'),
            monitor='val_dish_accuracy', mode='max', save_best_only=True),
        keras.callbacks.CSVLogger(
            os.path.join(OUTPUT_DIR, f'training_log_{phase}.csv')),
        keras.callbacks.EarlyStopping(monitor='val_dish_accuracy', mode='max',
                                      patience=3, restore_best_weights=True),
    ]

# %% [markdown]
# ## Train
# - `scratch`: everything trained from random weights (baseline).
# - `linear`: ImageNet backbone frozen, only the two heads learn.
# - `finetune`: heads first, then the top of the backbone with a low
#   learning rate (the model the app ships).

# %%
import time

started = time.time()
if EXPERIMENT == 'scratch':
    base.trainable = True
    compile_model(1e-3)
    model.fit(train_ds, validation_data=val_ds,
              epochs=EPOCHS_HEAD + EPOCHS_FINE, callbacks=callbacks('scratch'))
else:
    base.trainable = False
    compile_model(1e-3)
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD,
              callbacks=callbacks('head'))
    if EXPERIMENT == 'finetune':
        base.trainable = True
        cut = int(len(base.layers) * (1 - UNFREEZE_FRACTION))
        for layer in base.layers[:cut]:
            layer.trainable = False
        for layer in base.layers:
            if isinstance(layer, keras.layers.BatchNormalization):
                layer.trainable = False
        compile_model(1e-4)
        model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE,
                  callbacks=callbacks('fine'))
train_minutes = (time.time() - started) / 60
print(f'Training took {train_minutes:.1f} min')

# %% [markdown]
# ## Evaluate on the test set
# Dish top-1/top-3 accuracy, and component F1 over the labels each photo
# actually has. The component threshold is tuned on the validation set and
# written to `MODEL_CARD.md`, where the app reads it.

# %%
import json


def predict(ds):
    dish_true, comp_true, dish_prob, comp_prob = [], [], [], []
    for images, y in ds:
        out = model(images, training=False)
        dish_true.append(y['dish'].numpy())
        comp_true.append(y['components'].numpy())
        dish_prob.append(out['dish'].numpy())
        comp_prob.append(out['components'].numpy())
    if not dish_true:
        return None
    return (np.concatenate(dish_true), np.concatenate(comp_true),
            np.concatenate(dish_prob), np.concatenate(comp_prob))


def component_f1(comp_true, comp_prob, threshold):
    labels, mask = comp_true[:, :N_COMP], comp_true[:, N_COMP:]
    guess = (comp_prob >= threshold) & (mask > 0)
    truth = (labels > 0) & (mask > 0)
    tp, fp, fn = (guess & truth).sum(), (guess & ~truth).sum(), (~guess & truth).sum()
    return 2 * tp / max(1, 2 * tp + fp + fn)


val_pred, test_pred = predict(val_ds), predict(test_ds)
threshold = 0.6
if val_pred is not None and val_pred[1][:, N_COMP:].sum() > 0:
    grid = [round(t, 2) for t in np.arange(0.3, 0.81, 0.05)]
    threshold = max(grid, key=lambda t: component_f1(val_pred[1], val_pred[3], t))
thresholds = {
    'threshold_checked': float(threshold),
    'threshold_ask': float(round(max(0.15, threshold - 0.3), 2)),
    'threshold_confident_dish': 0.5,
}

results = {'experiment': EXPERIMENT, 'backbone': BACKBONE,
           'quick_test': QUICK_TEST, 'train_minutes': round(train_minutes, 1),
           'photos': {'train': len(train), 'val': len(val), 'test': len(test)},
           **thresholds}
if test_pred is not None:
    dish_true, comp_true, dish_prob, comp_prob = test_pred
    top3 = np.argsort(-dish_prob, axis=1)[:, :3]
    results['dish_top1'] = float((top3[:, 0] == dish_true).mean())
    results['dish_top3'] = float((top3 == dish_true[:, None]).any(axis=1).mean())
    # Only photos with component labels (VietFood67, the team's own) count.
    results['component_f1'] = (
        float(component_f1(comp_true, comp_prob, threshold))
        if comp_true[:, N_COMP:].sum() > 0 else None)
    per_dish = {}
    for i, code in enumerate(OUTPUTS):
        rows = dish_true == i
        if rows.any():
            per_dish[code] = round(float((top3[rows, 0] == i).mean()), 3)
    results['dish_accuracy'] = per_dish
print(json.dumps({k: v for k, v in results.items() if k != 'dish_accuracy'},
                 indent=2))
with open(os.path.join(OUTPUT_DIR, 'results.json'), 'w') as f:
    json.dump(results, f, indent=2)

# %% [markdown]
# ## Export the files the app reads
# float16 TFLite, checked against the contract before writing.

# %%
from datetime import date

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite = converter.convert()
model_path = os.path.join(OUTPUT_DIR, 'food_v1.tflite')
with open(model_path, 'wb') as f:
    f.write(tflite)

interpreter = tf.lite.Interpreter(model_content=tflite)
interpreter.allocate_tensors()
(inp,) = interpreter.get_input_details()
outs = interpreter.get_output_details()
assert list(inp['shape']) == [1, IMG, IMG, 3] and inp['dtype'] == np.float32
assert sorted(int(o['shape'][-1]) for o in outs) == sorted([N_DISH, N_COMP])
# The converted model must agree with Keras on a real photo.
sample = next(iter(test_ds if test else val_ds))[0][:1]
interpreter.set_tensor(inp['index'], sample.numpy())
interpreter.invoke()
lite_dish = next(interpreter.get_tensor(o['index'])
                 for o in outs if o['shape'][-1] == N_DISH)
keras_dish = model(sample, training=False)['dish'].numpy()
assert np.abs(lite_dish - keras_dish).max() < 0.02, 'TFLite differs from Keras'

with open(os.path.join(OUTPUT_DIR, 'dishes.txt'), 'w') as f:
    f.write('\n'.join(OUTPUTS) + '\n')
with open(os.path.join(OUTPUT_DIR, 'components.txt'), 'w') as f:
    f.write('\n'.join(COMPONENTS) + '\n')

size_mb = len(tflite) / 1e6


def metric(name):
    value = results.get(name)
    return 'chưa có nhãn thành phần' if value is None else f'{value:.3f}'

sources = Counter(s['source'] for s in train + val + test)
card = f"""# MODEL_CARD – food_v1

- Ngày train: {date.today().isoformat()}
- Contract: {CONTRACT_VERSION} ({len(DISHES)} món{' + lớp khac' if USE_OTHER else ''}, {N_COMP} thành phần)
- Kiến trúc: {BACKBONE}, thí nghiệm `{EXPERIMENT}`{' (CHẠY THỬ, KHÔNG DÙNG THẬT)' if QUICK_TEST else ''}
- Dữ liệu: {len(train)} train / {len(val)} val / {len(test)} test
- Nguồn ảnh: {', '.join(f'{k}: {v}' for k, v in sources.most_common())}
- Kích thước: {size_mb:.1f} MB (float16)
- Thời gian train: {train_minutes:.0f} phút

## Kết quả trên tập test
- Món, top-1: {metric('dish_top1')}
- Món, top-3: {metric('dish_top3')}
- Thành phần, F1: {metric('component_f1')}

## Ngưỡng (app đọc các dòng này)
threshold_checked: {thresholds['threshold_checked']}
threshold_ask: {thresholds['threshold_ask']}
threshold_confident_dish: {thresholds['threshold_confident_dish']}

## Hạn chế
- Tập test chưa có ảnh tự chụp: contract yêu cầu ít nhất 30%.
- Nhãn thành phần chỉ có ở ảnh VietFood67 và ảnh tự gán; các ảnh còn lại
  chỉ dạy phần đoán món.
"""
with open(os.path.join(OUTPUT_DIR, 'MODEL_CARD.md'), 'w', encoding='utf-8') as f:
    f.write(card)
print(card)
print('Download from Output:', sorted(os.listdir(OUTPUT_DIR)))
