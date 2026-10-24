# %% [markdown]
# # MacroRunner – train the plate detector (YOLO)
#
# Trains the second model of `docs/MODEL_CONTRACT.md` (contract 1.6, §7): a
# YOLO11n that finds each food on a plate with a box, so a plate of plain
# rice and chicken breast comes out as "com" and "ga" instead of the dish
# the classifier knows best. 21 classes, each one an app component or a
# group of variants. The result is the three files the app reads from
# `assets/models/`: `detector.tflite`, `detector_classes.txt` and
# `DETECTOR_CARD.md`.
#
# Data: the boxes VietFood67 already has, and MyFood's masks turned into
# boxes. Each keeps its own train/val/test split.
#
# **On Google Colab**
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. The Kaggle key in *Secrets* (the key icon on the left), as for the food
#    model: `KAGGLE_API_TOKEN` with the `KGAT_...` value, notebook access on.
# 3. *Runtime → Run all*, then allow Google Drive in the window that opens
#    within the first seconds. VietFood67 downloads once per session (26 GB,
#    about 15 minutes). Results go to Google Drive, folder
#    `macrorunner_train/detector_yolo11n`.
# 4. Run once with `QUICK_TEST = True` (about 25 minutes, most of it the
#    download), then set `QUICK_TEST = False` and run all again in the same
#    session, so nothing downloads twice.
# 5. Free Colab ends a session after about 5 hours. At `TIME_LIMIT_HOURS`
#    training stops by itself after an epoch, and the notebook still tests
#    and exports the best epoch so far. Then, or if the session was cut off
#    anyway, run all again with the same settings: training continues from
#    `last.pt` in Drive.
#
# **On Kaggle**: add the dataset `thomasnguyen6868/vietfood68`, turn the GPU
# and Internet on (MyFood downloads from Zenodo), Save & Run All. The files
# are in the *Output* tab.
#
# Ultralytics is AGPL-3.0; VietFood67 is CC BY-NC-SA 4.0; MyFood is CC BY 4.0.

# %%
import os
import sys
import time

NOTEBOOK_STARTED = time.time()


def stage(text):
    """One timestamped log line, so a long run shows where it is."""
    minutes = (time.time() - NOTEBOOK_STARTED) / 60
    print(f'[{minutes:6.1f} min] {text}', flush=True)


QUICK_TEST = True        # True: 300 photos, 2 epochs at 320 px.
MODEL = os.environ.get('MODEL', 'yolo11n.pt')   # COCO weights to start from
IMGSZ = 320 if QUICK_TEST else 640
EPOCHS = 2 if QUICK_TEST else 80
BATCH = 16 if QUICK_TEST else 32
PATIENCE = 20            # epochs without a better val mAP before stopping
SEED = 0
# Photos with a box around a whole dish (phở, cơm tấm…) are left out: the
# rice and eggs inside such a box are often not boxed themselves, and
# training on them would teach the model they are background.
KEEP_DISH_PHOTOS = False
# Photos with none of the 21 foods, kept as background, as a share of the
# photos that have some.
BACKGROUND_SHARE = 0.1
LONG_SIDE = 640          # photos are shrunk to this once, for fast loading
ULTRALYTICS_VERSION = '8.4.185'

ON_COLAB = 'google.colab' in sys.modules
ON_KAGGLE = bool(os.environ.get('KAGGLE_KERNEL_RUN_TYPE'))
# Kaggle stops a run at 12 hours, free Colab after about 5. 0: no limit.
TIME_LIMIT_HOURS = float(os.environ.get(
    'TIME_LIMIT_HOURS', 11 if ON_KAGGLE else 4.6 if ON_COLAB else 0))
# Kept after training for the test and the export.
FINISH_MINUTES = 20
INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/kaggle/working')
WORK_DIR = os.environ.get('WORK_DIR', '/tmp/detector_data')
VF67_REF = 'thomasnguyen6868/vietfood68'
MYFOOD_URL = ('https://zenodo.org/records/4041488/files/'
              'MyFood%20Dataset.zip?download=1')
DOWNLOAD_MYFOOD = os.environ.get('DOWNLOAD_MYFOOD', '1') == '1'
COLAB_ROOT = os.environ.get('COLAB_ROOT', '/content')

# %% [markdown]
# ## Setup: Ultralytics, Drive, the datasets

# %%
import shutil
import subprocess

try:
    import ultralytics
    if ultralytics.__version__ != ULTRALYTICS_VERSION and (ON_COLAB or ON_KAGGLE):
        raise ImportError
except ImportError:
    # The version this notebook was tested with: newer ones change the
    # export.
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q',
                    f'ultralytics=={ULTRALYTICS_VERSION}'], check=True)
    import ultralytics
stage(f'Ultralytics {ultralytics.__version__}')

if ON_COLAB:
    from google.colab import drive
    print('Allow Google Drive access in the window that opens now.', flush=True)
    drive.mount(os.path.join(COLAB_ROOT, 'drive'))
    OUTPUT_DIR = os.path.join(COLAB_ROOT, 'drive', 'MyDrive', 'macrorunner_train',
                              'detector_yolo11n' + ('_quick' if QUICK_TEST else ''))
    WORK_DIR = os.path.join(COLAB_ROOT, 'detector_data')

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
    stage(f'Disk free: {shutil.disk_usage(COLAB_ROOT).free / 1e9:.0f} GB')

EXTRA_ROOT = os.path.join(WORK_DIR, 'extra')
os.makedirs(EXTRA_ROOT, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

myfood_dir = os.path.join(EXTRA_ROOT, 'myfood')
if DOWNLOAD_MYFOOD and not os.path.isdir(myfood_dir):
    import urllib.request
    import zipfile
    stage('Downloading MyFood ...')
    try:
        urllib.request.urlretrieve(MYFOOD_URL, myfood_dir + '.zip')
        with zipfile.ZipFile(myfood_dir + '.zip') as z:
            z.extractall(myfood_dir + '.part')
        os.replace(myfood_dir + '.part', myfood_dir)
        os.remove(myfood_dir + '.zip')
    except Exception as error:   # no Internet: train without it
        print(f'  MyFood FAILED ({error}): eggs, steak and chicken breast get '
              'fewer boxes. On Kaggle, turn Internet on.', flush=True)
stage(f'Photos from {INPUT_ROOT} and {EXTRA_ROOT} | results to {OUTPUT_DIR}')

# %% [markdown]
# ## Contract
# Class codes in output order (contract 1.6, §7.1). They must match
# `detector_classes.txt`, which this notebook writes at the end.

# %%
CONTRACT_VERSION = '1.6'
CLASSES = [
    'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
    'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
    'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
]
assert len(CLASSES) == 21
CLASS_INDEX = {code: i for i, code in enumerate(CLASSES)}

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
VF_CLASS = {
    'Com': 'com', 'Bun': 'bun', 'Mi': 'mi', 'Banh mi': 'banh_mi_o',
    'Thit ga': 'ga', 'Thit kho': 'thit_kho', 'Thit nuong': 'thit_nuong',
    'Thit heo': 'heo', 'Heo quay': 'heo', 'Thit bo': 'bo', 'Ca': 'ca',
    'Tom': 'tom', 'Muc': 'muc', 'Trung': 'trung', 'Dau hu': 'dau_hu',
    'Cha': 'cha', 'Cha gio': 'cha_gio', 'Rau': 'rau', 'Bong cai': 'rau',
    'Dua leo': 'dua_leo_ca_chua', 'Ca chua': 'dua_leo_ca_chua',
    'Dua chua': 'do_chua', 'Khoai tay chien': 'khoai_tay_chien',
    'Canh': 'canh',
}
# Boxes around a whole dish (see KEEP_DISH_PHOTOS).
VF_DISH_BOXES = {
    'Banh canh', 'Banh chung', 'Banh cuon', 'Banh khot', 'Banh trang tron',
    'Banh xeo', 'Bo kho', 'Bo la lot', 'Bun bo Hue', 'Bun cha', 'Bun dau',
    'Bun mam', 'Bun rieu', 'Com tam', 'Goi cuon', 'Hamburger', 'Hu tieu',
    'Kho qua thit', 'Lau', 'Pho', 'Salad', 'Xoi', 'Banh beo', 'Cao lau',
    'Mi Quang', 'Com chien Duong Chau', 'Bun cha ca', 'Com chien ga',
    'Chao long', 'Nom hoa chuoi', 'Nui xao bo', 'Sup cua',
}
assert set(VF_CLASS) | VF_DISH_BOXES <= set(VF_NAMES)
# MyFood: mask value → class (1 is food it left unnamed, 2 apple, 3 bean:
# background).
MYFOOD_CLASS = {4: 'trung', 5: 'ga', 6: 'com', 7: 'rau', 8: 'mi', 9: 'trung',
                10: 'bo'}
MIN_PIECE = 0.004        # MyFood specks smaller than this share of the photo

# %% [markdown]
# ## Build the YOLO dataset
# Each photo is shrunk once and written with its remapped boxes to
# `WORK_DIR/yolo/{images,labels}/{train,val,test}`.

# %%
import random
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image, ImageOps

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
SPLITS = {'train': 'train', 'training': 'train', 'valid': 'val', 'val': 'val',
          'validation': 'val', 'test': 'test', 'testing': 'test'}
YOLO_DIR = os.path.join(WORK_DIR, 'yolo')
random.seed(SEED)
skipped = Counter()


def split_of(path):
    for part in reversed(path.replace('\\', '/').split('/')):
        if part.lower() in SPLITS:
            return SPLITS[part.lower()]
    return 'train'


def is_detection_root(folder):
    return (os.path.isdir(os.path.join(folder, 'images')) and
            os.path.isdir(os.path.join(folder, 'labels')))


def find_roots(top, test):
    found = []
    for folder, dirs, files in os.walk(top, followlinks=True):
        if test(folder, files):
            found.append(folder)
            dirs[:] = []
    return found


def vf67_items(root):
    """(image, split, [(class, cx, cy, w, h)]) for each usable photo."""
    images = {}
    for folder, _, names in os.walk(os.path.join(root, 'images'),
                                    followlinks=True):
        for name in names:
            stem, ext = os.path.splitext(name)
            if ext.lower() in IMAGE_EXT:
                rel = os.path.relpath(os.path.join(folder, stem),
                                      os.path.join(root, 'images'))
                images.setdefault(rel, os.path.join(folder, name))
    stage(f'VietFood67: {len(images)} images in {root}')
    kept, background = [], []
    for folder, _, names in os.walk(os.path.join(root, 'labels'),
                                    followlinks=True):
        for name in sorted(names):
            if not name.endswith('.txt'):
                continue
            path = os.path.join(folder, name)
            rel = os.path.splitext(
                os.path.relpath(path, os.path.join(root, 'labels')))[0]
            image = images.get(rel)
            if image is None:
                skipped['vf67: no image'] += 1
                continue
            boxes, names_seen = [], set()
            with open(path) as f:
                for line in f:
                    parts = line.split()
                    if len(parts) < 5 or not parts[0].isdigit():
                        continue
                    index = int(parts[0])
                    if index >= len(VF_NAMES):
                        continue
                    try:
                        cx, cy, w, h = (float(p) for p in parts[1:5])
                    except ValueError:
                        continue
                    vf_name = VF_NAMES[index]
                    names_seen.add(vf_name)
                    if vf_name in VF_CLASS and w > 0 and h > 0:
                        boxes.append((CLASS_INDEX[VF_CLASS[vf_name]], cx, cy,
                                      w, h))
            if names_seen & VF_DISH_BOXES and not KEEP_DISH_PHOTOS:
                skipped['vf67: whole-dish box'] += 1
                continue
            item = (image, split_of(rel), boxes)
            (kept if boxes else background).append(item)
    random.shuffle(background)
    background = background[:int(BACKGROUND_SHARE * len(kept))]
    stage(f'VietFood67: {len(kept)} photos with boxes, {len(background)} '
          'background')
    return kept + background


def myfood_items(root):
    import cv2   # comes with Ultralytics
    items = []
    for split in ('train', 'val', 'test'):
        folder = os.path.join(root, split)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            stem, ext = os.path.splitext(name)
            mask_path = os.path.join(root, f'{split}_ann', stem + '.png')
            if ext.lower() not in IMAGE_EXT or not os.path.exists(mask_path):
                skipped['myfood: no mask'] += 1
                continue
            with Image.open(mask_path) as mask:
                values = np.asarray(mask)
            # Palette and grey masks hold the class itself, RGB(A) ones in red.
            if values.ndim == 3:
                values = values[..., 0]
            height, width = values.shape
            boxes = []
            for value, code in MYFOOD_CLASS.items():
                count, _, stats, _ = cv2.connectedComponentsWithStats(
                    (values == value).astype(np.uint8))
                for left, top, w, h, area in stats[1:]:   # 0 is the rest
                    if area < MIN_PIECE * values.size:
                        continue
                    boxes.append((CLASS_INDEX[code], (left + w / 2) / width,
                                  (top + h / 2) / height, w / width,
                                  h / height))
            if boxes:
                items.append((os.path.join(folder, name), split, boxes))
    stage(f'MyFood: {len(items)} photos with boxes')
    return items


def write(index_item):
    index, (source, image, split, boxes) = index_item
    name = f'{source}_{index:06d}'
    target = os.path.join(YOLO_DIR, 'images', split, name + '.jpg')
    try:
        with Image.open(image) as im:
            # Turned as the camera meant, like Ultralytics reads the boxes.
            im = ImageOps.exif_transpose(im).convert('RGB')
            im.thumbnail((LONG_SIDE, LONG_SIDE))
            im.save(target, quality=90)
    except Exception:
        return None
    with open(os.path.join(YOLO_DIR, 'labels', split, name + '.txt'), 'w') as f:
        for c, cx, cy, w, h in boxes:
            # Boxes that run past the edge are cut at it.
            left, top = max(0.0, cx - w / 2), max(0.0, cy - h / 2)
            right, bottom = min(1.0, cx + w / 2), min(1.0, cy + h / 2)
            if right - left > 0.005 and bottom - top > 0.005:
                f.write(f'{c} {(left + right) / 2:.6f} {(top + bottom) / 2:.6f} '
                        f'{right - left:.6f} {bottom - top:.6f}\n')
    return split, boxes


items = []
for root in find_roots(INPUT_ROOT, lambda folder, _: is_detection_root(folder)):
    items += [('vf67', *item) for item in vf67_items(root)]
for root in find_roots(EXTRA_ROOT, lambda folder, files:
                       os.path.isdir(os.path.join(folder, 'train_ann'))):
    items += [('myfood', *item) for item in myfood_items(root)]
if QUICK_TEST:
    random.shuffle(items)
    items = items[:300]
    # Every split needs photos, even in a quick test.
    for i, split in enumerate(['val', 'test']):
        if not any(item[2] == split for item in items) and items:
            items[i] = (items[i][0], items[i][1], split, items[i][3])
if not items:
    raise RuntimeError(f'No photos with boxes under {INPUT_ROOT}: add '
                       f'{VF67_REF}.')

shutil.rmtree(YOLO_DIR, ignore_errors=True)
for kind in ('images', 'labels'):
    for split in ('train', 'val', 'test'):
        os.makedirs(os.path.join(YOLO_DIR, kind, split), exist_ok=True)
boxes_per_split = {split: Counter() for split in ('train', 'val', 'test')}
photos_per_split = Counter()
with ThreadPoolExecutor(16) as pool:
    for done, result in enumerate(pool.map(write, enumerate(items))):
        if result is None:
            skipped['unreadable photo'] += 1
            continue
        split, boxes = result
        photos_per_split[split] += 1
        boxes_per_split[split].update(CLASSES[c] for c, *_ in boxes)
        if done % 5000 == 4999:
            stage(f'{done + 1} of {len(items)} photos written')
stage(f'Photos: {dict(photos_per_split)} | skipped: {dict(skipped)}')
print(f'{"class":18} {"train":>7} {"val":>6} {"test":>6}')
for code in CLASSES:
    print(f'{code:18} ' + ' '.join(f'{boxes_per_split[s][code]:>{w}}'
                                   for s, w in (('train', 7), ('val', 6),
                                                ('test', 6))))

DATA_YAML = os.path.join(WORK_DIR, 'data.yaml')
with open(DATA_YAML, 'w') as f:
    f.write(f'path: {YOLO_DIR}\ntrain: images/train\nval: images/val\n'
            'test: images/test\nnames:\n')
    for i, code in enumerate(CLASSES):
        f.write(f'  {i}: {code}\n')

# %% [markdown]
# ## Train
# Ultralytics saves `last.pt` and `best.pt` to `OUTPUT_DIR/train/weights`
# after every epoch. A later run with the same settings resumes `last.pt`.

# %%
import json

from ultralytics import YOLO

RUN_DIR = os.path.join(OUTPUT_DIR, 'train')
LAST = os.path.join(RUN_DIR, 'weights', 'last.pt')
BEST = os.path.join(RUN_DIR, 'weights', 'best.pt')
PROGRESS = os.path.join(OUTPUT_DIR, 'progress.json')


class OutOfTime(Exception):
    pass


epoch_started = [time.time()]
epoch_seconds = []


def check_time(trainer):
    """After each saved epoch: stop if the next one would not finish in time,
    leaving last.pt resumable (Ultralytics strips it once training ends)."""
    epoch_seconds.append(time.time() - epoch_started[0])
    epoch_started[0] = time.time()
    with open(PROGRESS + '.tmp', 'w') as f:
        json.dump({'epoch': trainer.epoch + 1, 'epochs': trainer.epochs,
                   'best_fitness': float(trainer.best_fitness or 0)}, f)
    os.replace(PROGRESS + '.tmp', PROGRESS)
    if not TIME_LIMIT_HOURS or trainer.stop or trainer.epoch + 1 >= trainer.epochs:
        return
    left = (TIME_LIMIT_HOURS * 3600 - FINISH_MINUTES * 60 -
            (time.time() - NOTEBOOK_STARTED))
    if left < max(epoch_seconds[-3:]) * 1.1:
        raise OutOfTime(f'stopped after epoch {trainer.epoch + 1} of '
                        f'{trainer.epochs} to keep time for the export')


finished = True
resume = os.path.exists(LAST)
if resume:
    try:
        import torch
        resume = torch.load(LAST, map_location='cpu',
                            weights_only=False).get('epoch', -1) != -1
    except Exception:
        resume = False
if os.path.exists(BEST) and not resume:
    stage('Training already finished: testing and exporting best.pt. Delete '
          f'{RUN_DIR} to train again.')
else:
    model = YOLO(LAST if resume else MODEL)
    model.add_callback('on_fit_epoch_end', check_time)
    stage(('Resuming ' + LAST) if resume else f'Training from {MODEL}')
    try:
        if resume:
            model.train(resume=True)
        else:
            model.train(data=DATA_YAML, epochs=EPOCHS, imgsz=IMGSZ, batch=BATCH,
                        patience=PATIENCE, seed=SEED, project=OUTPUT_DIR,
                        name='train', exist_ok=True, workers=2 if ON_COLAB else 4,
                        plots=not QUICK_TEST, cos_lr=True, close_mosaic=10)
    except OutOfTime as stop:
        finished = False
        stage(f'Time limit: {stop}. Run all again to continue from last.pt.')
    stage('Training done' if finished else 'Training paused')

# %% [markdown]
# ## Test, then export for the app

# %%
model = YOLO(BEST)
# The box threshold where mean F1 over the classes peaks on val, within sane
# bounds; the test split only measures.
val = model.val(data=DATA_YAML, split='val', imgsz=IMGSZ, batch=BATCH,
                plots=False, project=OUTPUT_DIR, name='val', exist_ok=True)
f1 = np.asarray(val.box.f1_curve)
threshold_box = 0.35
if f1.size:
    confidence = np.linspace(0, 1, f1.shape[-1])
    threshold_box = float(np.clip(confidence[int(f1.mean(0).argmax())], 0.2, 0.6))
test = model.val(data=DATA_YAML, split='test', imgsz=IMGSZ, batch=BATCH,
                 plots=False, project=OUTPUT_DIR, name='test', exist_ok=True)
names = model.names
per_class = {}
for i, c in enumerate(test.box.ap_class_index):
    per_class[names[int(c)]] = {'map50': float(test.box.ap50[i]),
                                'map50_95': float(test.box.ap[i])}
results = {'map50': float(test.box.map50), 'map50_95': float(test.box.map),
           'precision': float(test.box.mp), 'recall': float(test.box.mr),
           'threshold_box': threshold_box, 'per_class': per_class,
           'finished': finished, 'photos': dict(photos_per_split)}
stage(f"Test: mAP50 {results['map50']:.3f}, mAP50-95 {results['map50_95']:.3f}, "
      f'box threshold {threshold_box:.2f}')

EXPORT_DIR = os.path.join(OUTPUT_DIR, 'export')
os.makedirs(EXPORT_DIR, exist_ok=True)
exported = {}
for label, quantize in (('detector.tflite', None),
                        ('detector_int8.tflite', 'w8a32')):
    try:
        path = model.export(format='litert', imgsz=IMGSZ, quantize=quantize)
        shutil.copy(path, os.path.join(EXPORT_DIR, label))
        exported[label] = os.path.getsize(path)
    except Exception as error:   # LiteRT exports on Linux x86 and macOS only
        print(f'{label}: export FAILED ({error})', flush=True)
try:
    shutil.copy(model.export(format='onnx', imgsz=IMGSZ, simplify=True),
                os.path.join(EXPORT_DIR, 'detector.onnx'))
except Exception as error:
    print(f'detector.onnx: export FAILED ({error})', flush=True)
shutil.copy(BEST, os.path.join(EXPORT_DIR, 'detector_best.pt'))
with open(os.path.join(EXPORT_DIR, 'detector_classes.txt'), 'w',
          encoding='utf-8') as f:
    f.write('\n'.join(names[i] for i in range(len(names))) + '\n')
assert [names[i] for i in range(len(names))] == CLASSES

# %% [markdown]
# ## Check the exported model the way the app reads it
# Letterbox to the input size, read the boxes from the one output, keep the
# ones above the threshold, then per-class NMS (contract §7.2). The count
# must be close to what Ultralytics itself finds.

# %%


def letterbox(image, size):
    im = ImageOps.exif_transpose(image).convert('RGB')
    scale = size / max(im.size)
    resized = im.resize((max(1, round(im.width * scale)),
                         max(1, round(im.height * scale))), Image.BILINEAR)
    canvas = Image.new('RGB', (size, size), (114, 114, 114))
    canvas.paste(resized, ((size - resized.width) // 2,
                           (size - resized.height) // 2))
    return np.asarray(canvas, dtype=np.float32) / 255


def iou(a, b):
    left, top = max(a[0], b[0]), max(a[1], b[1])
    right, bottom = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, right - left) * max(0, bottom - top)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0


def app_boxes(output, classes, threshold, iou_limit=0.5):
    """[(class, score, (left, top, right, bottom))] as the app finds them."""
    out = output[0]
    if out.shape[0] != 4 + classes:
        out = out.T
    if out[:4].max() > 2:
        out = out.copy()
        out[:4] /= IMGSZ
    scores = out[4:]
    best = scores.argmax(0)
    score = scores.max(0)
    found = []
    for a in np.nonzero(score >= threshold)[0]:
        cx, cy, w, h = out[:4, a]
        found.append((int(best[a]), float(score[a]),
                      (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)))
    found.sort(key=lambda d: -d[1])
    kept = []
    for d in found:
        if all(k[0] != d[0] or iou(k[2], d[2]) <= iou_limit for k in kept):
            kept.append(d)
    return kept


tflite = os.path.join(EXPORT_DIR, 'detector.tflite')
onnx_file = os.path.join(EXPORT_DIR, 'detector.onnx')
run_model = None
if os.path.exists(tflite):
    from ai_edge_litert.interpreter import Interpreter
    interpreter = Interpreter(model_path=tflite)
    interpreter.allocate_tensors()
    tin = interpreter.get_input_details()[0]
    tout = interpreter.get_output_details()[0]
    input_shape, output_shape = list(tin['shape']), list(tout['shape'])

    def run_model(x):
        interpreter.set_tensor(tin['index'], x)
        interpreter.invoke()
        return interpreter.get_tensor(tout['index'])
elif os.path.exists(onnx_file):
    # No LiteRT here (Windows): the same check on the ONNX copy, whose boxes
    # are in pixels.
    import onnxruntime
    session = onnxruntime.InferenceSession(onnx_file)
    input_shape = list(session.get_inputs()[0].shape)
    output_shape = list(session.get_outputs()[0].shape)

    def run_model(x):
        return session.run(None, {session.get_inputs()[0].name: x})[0]
if run_model is not None:
    print('input', input_shape, '| output', output_shape)
    test_images = sorted(os.listdir(os.path.join(YOLO_DIR, 'images', 'test')))[:20]
    same = 0
    for name in test_images:
        path = os.path.join(YOLO_DIR, 'images', 'test', name)
        with Image.open(path) as im:
            x = letterbox(im, IMGSZ)[None]
        if input_shape[1] == 3:
            x = np.ascontiguousarray(x.transpose(0, 3, 1, 2))
        ours = app_boxes(run_model(x), len(CLASSES), threshold_box)
        theirs = model.predict(path, imgsz=IMGSZ, conf=threshold_box,
                               iou=0.5, verbose=False)[0].boxes
        same += abs(len(ours) - len(theirs)) <= 1
    print(f'app-style decoding matches Ultralytics on {same} of '
          f'{len(test_images)} test photos (within one box)')
    results['app_decoding_matches'] = f'{same}/{len(test_images)}'
    results['input_shape'] = [int(v) for v in input_shape]
    results['output_shape'] = [int(v) for v in output_shape]

# %% [markdown]
# ## Detector card

# %%
from datetime import date

lines = [
    '# Detector card',
    '',
    f'contract_version: {CONTRACT_VERSION}',
    f'threshold_box: {threshold_box:.2f}',
    'threshold_iou: 0.5',
    '',
    f'- Trained: {date.today().isoformat()}, {MODEL} with Ultralytics '
    f'{ultralytics.__version__}, {IMGSZ} px'
    + ('' if finished else ' (training not finished: best epoch so far)')
    + (', QUICK TEST' if QUICK_TEST else ''),
    f"- Photos: {dict(photos_per_split)} (VietFood67 boxes, MyFood masks)",
    f"- Test: mAP50 {results['map50']:.3f}, mAP50-95 {results['map50_95']:.3f}, "
    f"precision {results['precision']:.3f}, recall {results['recall']:.3f}",
    f'- Files: ' + ', '.join(f'{k} {v / 1e6:.1f} MB' for k, v in exported.items()),
    '',
    '| class | test boxes | mAP50 | mAP50-95 |',
    '|---|---|---|---|',
]
for code in CLASSES:
    row = per_class.get(code)
    lines.append(f'| {code} | {boxes_per_split["test"][code]} | '
                 + (f"{row['map50']:.3f} | {row['map50_95']:.3f} |" if row
                    else '– | – |'))
card = '\n'.join(lines) + '\n'
with open(os.path.join(EXPORT_DIR, 'DETECTOR_CARD.md'), 'w', encoding='utf-8') as f:
    f.write(card)
with open(os.path.join(EXPORT_DIR, 'results.json'), 'w') as f:
    json.dump(results, f, indent=1)
print(card)
stage(f'Files for the app in {EXPORT_DIR}: detector.tflite (or '
      'detector_int8.tflite), detector_classes.txt, DETECTOR_CARD.md')
