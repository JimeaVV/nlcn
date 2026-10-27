# %% [markdown]
# # MacroRunner – box the foods on photos that have none (for the detector)
#
# The plate detector (`train_detector.ipynb`) learns from photos with a box
# around each food. The Vietnamese dish datasets the food model trains on
# (30VNFoods, VinaFood21, 20FoodVN) have tens of thousands of real plates,
# but only a dish name per photo. This notebook boxes the foods on them:
#
# 1. Grounding DINO, a large model that finds things named in words, looks
#    for the foods each dish holds ("rice", "grilled pork chop", "fried egg"
#    for cơm tấm). The dish says which class a box is: the meat on a cơm tấm
#    plate is `thit_nuong`, on a thịt kho trứng plate `thit_kho`.
# 2. The current plate detector checks it: a weak box is kept only where the
#    detector also sees food, and a food the detector is sure of but the
#    prompts missed is added, so it is not learned as background.
#
# It also takes boxes of fries, shrimp, tomatoes, cucumbers, broccoli and
# cabbage on a plate or bowl from Open Images, and drops the photos where
# rice, noodles or meat sit unboxed next to them.
#
# The result, `autolabel.zip`, is one more training set for
# `train_detector.ipynb`. Its boxes are machine-made, so they go to the train
# split only: val and test stay the hand-made boxes.
#
# **On Google Colab**
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. The Kaggle key in *Secrets*, as for the other notebooks:
#    `KAGGLE_API_TOKEN`, notebook access on.
# 3. *Runtime → Run all*, then allow Google Drive in the window that opens
#    within the first seconds. About 2 hours: 20 minutes of downloads, then
#    about 0.3 s per photo. The zip and a `preview.jpg` of 24 boxed photos go
#    to Google Drive, folder `macrorunner_train/detector_autolabel`.
# 4. Look at `preview.jpg`. Then run `train_detector.ipynb` with the same
#    Google account: it finds the zip in Drive by itself.
#
# **On Kaggle**: add the datasets `quandang/vietnamese-foods`,
# `sonbui25/vinafood21` and `lnguynanhnht/20foodvn`, turn the GPU and
# Internet on, Save & Run All. The files are in the *Output* tab.
#
# Grounding DINO is Apache-2.0; Open Images boxes are CC BY 4.0 (photos: the
# licence each one lists, mostly CC BY 2.0); the dish datasets are for
# research use.

# %%
import os
import sys
import time

NOTEBOOK_STARTED = time.time()


def stage(text):
    """One timestamped log line, so a long run shows where it is."""
    minutes = (time.time() - NOTEBOOK_STARTED) / 60
    print(f'[{minutes:6.1f} min] {text}', flush=True)


QUICK_TEST = True        # True: 20 photos per dish, 10 per Open Images class.
PER_DISH = 20 if QUICK_TEST else 700
OI_PER_CLASS = 10 if QUICK_TEST else 1500
GD_MODEL = os.environ.get('GD_MODEL', 'IDEA-Research/grounding-dino-base')
# The plate detector that checks the boxes: a shared link to a finished
# run's `export/detector_best.pt`, or a path. This one is the YOLO11n
# fine-tuned with FoodInsSeg (APK 135).
TEACHER_FROM = os.environ.get(
    'TEACHER_FROM',
    'https://drive.google.com/file/d/1YZwTnS7PStI8HpLIQcniMGiBMygvcNmR/view')
# Grounding DINO scores: below BOX_MIN a box is dropped, from BOX_SURE it is
# kept alone; in between only where the detector sees food too.
BOX_MIN = 0.3
BOX_SURE = 0.45
TEXT_MIN = 0.25
TEACHER_AGREE = 0.25     # detector score that counts as "sees food there"
TEACHER_SURE = 0.6       # detector boxes added when the prompts missed them
MAX_AREA = 0.8           # boxes bigger than this share of the photo are dropped
UNSURE_SCORE = 0.4       # Open Images: unboxed rice, noodles or meat this sure
LONG_SIDE = 640          # photos are shrunk to this, as the detector notebook does
PREVIEW = 24
ULTRALYTICS_VERSION = '8.4.185'
SEED = 0

ON_COLAB = 'google.colab' in sys.modules
ON_KAGGLE = bool(os.environ.get('KAGGLE_KERNEL_RUN_TYPE'))
INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/kaggle/working')
WORK_DIR = os.environ.get('WORK_DIR', '/tmp/autolabel')
KAGGLE_DATASETS = [
    'quandang/vietnamese-foods',    # 30VNFoods
    'sonbui25/vinafood21',
    'lnguynanhnht/20foodvn',
]
DOWNLOAD_OPEN_IMAGES = os.environ.get('DOWNLOAD_OPEN_IMAGES', '1') == '1'
OI_BOXES = {
    'train': 'https://storage.googleapis.com/openimages/v6/'
             'oidv6-train-annotations-bbox.csv',   # 2.3 GB
}
OI_PHOTO = 'https://open-images-dataset.s3.amazonaws.com/{split}/{id}.jpg'
COLAB_ROOT = os.environ.get('COLAB_ROOT', '/content')

# %% [markdown]
# ## Setup: Drive, the datasets, the two models

# %%
import re
import shutil
import subprocess

try:
    import ultralytics
    if ultralytics.__version__ != ULTRALYTICS_VERSION and (ON_COLAB or ON_KAGGLE):
        raise ImportError
except ImportError:
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q',
                    f'ultralytics=={ULTRALYTICS_VERSION}'], check=True)
    import ultralytics
stage(f'Ultralytics {ultralytics.__version__}')

if ON_COLAB:
    from google.colab import drive
    print('Allow Google Drive access in the window that opens now.', flush=True)
    drive.mount(os.path.join(COLAB_ROOT, 'drive'))
    OUTPUT_DIR = os.path.join(COLAB_ROOT, 'drive', 'MyDrive', 'macrorunner_train',
                              'detector_autolabel' + ('_quick' if QUICK_TEST else ''))
    WORK_DIR = os.path.join(COLAB_ROOT, 'autolabel')

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
    for ref in KAGGLE_DATASETS:
        link = os.path.join(INPUT_ROOT, ref.split('/')[1])
        if os.path.lexists(link):
            continue
        stage(f'Downloading {ref} ...')
        try:
            os.symlink(kagglehub.dataset_download(ref), link)
        except Exception as error:
            raise RuntimeError(
                f'Could not download {ref}: {error}. Check the Colab secret '
                'KAGGLE_API_TOKEN, with notebook access on.') from error
os.makedirs(WORK_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def is_checkpoint(path):
    """True for a file torch.save wrote (a zip), not a web page."""
    with open(path, 'rb') as f:
        return f.read(2) == b'PK'


TEACHER = TEACHER_FROM
if not os.path.exists(TEACHER_FROM):
    TEACHER = os.path.join(WORK_DIR, 'teacher.pt')
    if not os.path.exists(TEACHER) or not is_checkpoint(TEACHER):
        stage(f'Copying the plate detector from {TEACHER_FROM} ...')
        try:
            import gdown
        except ImportError:
            subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'gdown'],
                           check=True)
            import gdown
        # By file id: Colab's gdown saves the page behind a /view link.
        match = re.search(r'/d/([\w-]{20,})|[?&]id=([\w-]{20,})', TEACHER_FROM)
        file_id = next(g for g in match.groups() if g) if match else TEACHER_FROM
        gdown.download(id=file_id, output=TEACHER + '.part', quiet=True)
        if not is_checkpoint(TEACHER + '.part'):
            raise RuntimeError('TEACHER_FROM gave a web page, not detector_best.pt:'
                               ' share it as "Anyone with the link".')
        os.replace(TEACHER + '.part', TEACHER)
stage(f'Photos from {INPUT_ROOT} | results to {OUTPUT_DIR}')

# %% [markdown]
# ## What each dish holds
# Class codes are the detector's (contract 1.6, §7.1). For each dish, the
# words Grounding DINO looks for and the class each one is. Dishes not
# listed here are not used: their foods are not detector classes (bánh
# xèo), the dish does not say which meat it is, or the noodles sit in soup
# (phở, bún bò, hủ tiếu, mì Quảng). VietFood67 boxes those as a whole dish,
# not as `bun` or `mi`, and Grounding DINO boxes the whole bowl as noodles.

# %%
CLASSES = [
    'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
    'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
    'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
]
CLASS_INDEX = {code: i for i, code in enumerate(CLASSES)}
MEATS = {'ga', 'thit_kho', 'thit_nuong', 'heo', 'bo'}
# Classes whose box may fill the photo: a bowl of soup, a bánh mì, a fish
# in its pot.
WHOLE = {'canh', 'banh_mi_o', 'ca'}
VERMICELLI = {'rice vermicelli': 'bun', 'herbs': 'rau'}
PROMPTS = {
    'com_tam': {'rice': 'com', 'grilled pork chop': 'thit_nuong',
                'fried egg': 'trung', 'steamed egg meatloaf': 'cha',
                'pickled vegetables': 'do_chua',
                'cucumber slices': 'dua_leo_ca_chua',
                'tomato slices': 'dua_leo_ca_chua'},
    'com_ga': {'rice': 'com', 'chicken': 'ga', 'herbs': 'rau',
               'cucumber slices': 'dua_leo_ca_chua',
               'tomato slices': 'dua_leo_ca_chua'},
    'thit_kho_trung': {'braised pork': 'thit_kho', 'boiled egg': 'trung',
                       'rice': 'com'},
    'ca_kho': {'braised fish': 'ca', 'rice': 'com'},
    'ga_nuong': {'grilled chicken': 'ga', 'herbs': 'rau',
                 'cucumber slices': 'dua_leo_ca_chua'},
    'goi_ga': {'shredded chicken': 'ga', 'herbs': 'rau'},
    'ca_ri': {'chicken': 'ga', 'baguette': 'banh_mi_o'},
    'bo_kho': {'beef chunks': 'bo', 'baguette': 'banh_mi_o'},
    'banh_mi': {'baguette sandwich': 'banh_mi_o'},
    'banh_mi_chao': {'fried egg': 'trung', 'baguette': 'banh_mi_o',
                     'pork sausage slices': 'cha'},
    'bun_cha': {**VERMICELLI, 'grilled pork': 'thit_nuong',
                'pickled vegetables': 'do_chua'},
    'bun_thit_nuong': {**VERMICELLI, 'grilled pork': 'thit_nuong',
                       'spring roll': 'cha_gio',
                       'pickled vegetables': 'do_chua'},
    'banh_hoi': {'grilled pork': 'thit_nuong', 'herbs': 'rau'},
    'bun_dau': {**VERMICELLI, 'fried tofu': 'dau_hu',
                'boiled pork slices': 'heo'},
    'banh_cuon': {'pork sausage slices': 'cha', 'herbs': 'rau'},
    'canh_chua': {'bowl of soup': 'canh'},
    'canh_khoai_mo': {'bowl of soup': 'canh'},
    'canh_kho_qua': {'bowl of soup': 'canh'},
}
assert {c for p in PROMPTS.values() for c in p.values()} <= set(CLASSES)
# Folder names (normalized) that are not already a dish code, as in
# train_food_model.py.
ALIASES = {
    'bun_dau_mam_tom': 'bun_dau', 'ca_kho_to': 'ca_kho', 'ca_loc_kho': 'ca_kho',
}
# Open Images class id → detector class, and the boxes that show the photo
# is food on a table (a plate, a bowl, "food").
OI_CLASS = {
    '/m/02y6n': 'khoai_tay_chien',   # French fries
    '/m/0ll1f78': 'tom',             # Shrimp (its Egg class is mostly
                                     # Easter eggs, so it is left out)
    '/m/07j87': 'dua_leo_ca_chua',   # Tomato
    '/m/015x4r': 'dua_leo_ca_chua',  # Cucumber
    '/m/0hkxq': 'rau',               # Broccoli
    '/m/0fbw6': 'rau',               # Cabbage
}
OI_TABLE = {'/m/050gv4', '/m/04kkgm', '/m/02wbm', '/m/01_bhs'}
# Vegetables need a plate or a bowl, not just "food": a market stall of
# tomatoes is food too.
OI_DISH = {'/m/050gv4', '/m/04kkgm', '/m/01_bhs'}
OI_ON_DISH = {'dua_leo_ca_chua', 'rau'}
# More boxes than this is a market stall or a pile of vegetables, not a
# plate.
OI_MAX_BOXES = 8
# Foods of ours that Open Images never boxes: a photo showing one of them is
# left out, so the detector does not learn it as background.
OI_UNSURE = {'rice': 'com', 'noodles': 'mi', 'meat': 'heo'}

# %% [markdown]
# ## Collect the dish photos

# %%
import csv
import hashlib
import random
import unicodedata
from collections import Counter, defaultdict

random.seed(SEED)
IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
GENERIC_FOLDERS = {'images', 'image', 'imgs', 'img', 'photos', 'pictures',
                   'data', 'dataset', 'train', 'training', 'test', 'testing',
                   'val', 'valid', 'validate', 'validation'}


def normalize(name):
    name = unicodedata.normalize('NFD', name.replace('đ', 'd').replace('Đ', 'D'))
    name = ''.join(c for c in name if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def dish_of(folder):
    """The dish a photo's folder names, e.g. 'com_tam' for .../Com tam/1.jpg."""
    for part in reversed(os.path.relpath(folder, INPUT_ROOT).split(os.sep)):
        key = normalize(part)
        if key in GENERIC_FOLDERS:
            continue
        key = ALIASES.get(key, key)
        return key if key in PROMPTS else None
    return None


per_dish = defaultdict(list)
seen_hashes = set()
duplicates = 0
for folder, _, names in os.walk(INPUT_ROOT, followlinks=True):
    photos = [n for n in sorted(names) if os.path.splitext(n)[1].lower() in IMAGE_EXT]
    if not photos:
        continue
    dish = dish_of(folder)
    if dish is None:
        continue
    for name in photos:
        per_dish[dish].append(os.path.join(folder, name))
dish_photos = []
for dish in sorted(per_dish):
    paths = per_dish[dish]
    random.shuffle(paths)
    kept = []
    for path in paths:
        if len(kept) >= PER_DISH:
            break
        # The datasets share photos: the same file is boxed once.
        with open(path, 'rb') as f:
            digest = hashlib.md5(f.read()).hexdigest()
        if digest in seen_hashes:
            duplicates += 1
            continue
        seen_hashes.add(digest)
        kept.append(path)
    dish_photos += [(dish, path) for path in kept]
    stage(f'{dish}: {len(paths)} photos, {len(kept)} to box')
stage(f'{len(dish_photos)} dish photos to box ({duplicates} duplicates skipped)')
if not dish_photos:
    raise RuntimeError(f'No photos of the dishes in PROMPTS under {INPUT_ROOT}: '
                       f'add {", ".join(KAGGLE_DATASETS)}.')

# %% [markdown]
# ## Open Images: photos with boxes of our foods on a plate or bowl

# %%
import urllib.request
from concurrent.futures import ThreadPoolExecutor

OI_DIR = os.path.join(WORK_DIR, 'open_images')
oi_photos = []   # (photo path, [(class, left, top, right, bottom)])
if DOWNLOAD_OPEN_IMAGES or os.path.isdir(OI_DIR):
    os.makedirs(OI_DIR, exist_ok=True)
    for split, url in OI_BOXES.items():
        table = os.path.join(OI_DIR, f'{split}-boxes.csv')
        if not os.path.exists(table):
            stage(f'Downloading the Open Images {split} boxes (2.3 GB) ...')
            urllib.request.urlretrieve(url, table + '.part')
            os.replace(table + '.part', table)
        stage(f'Reading {table} ...')
        boxes, labels, drawn = defaultdict(list), defaultdict(set), set()
        with open(table) as f:
            # ImageID,Source,LabelName,Confidence,XMin,XMax,YMin,YMax,
            # IsOccluded,IsTruncated,IsGroupOf,IsDepiction,IsInside. Split by
            # hand: csv.DictReader takes minutes over 14 million rows.
            next(f)
            for line in f:
                p = line.rstrip('\n').split(',')
                label = p[2]
                if label not in OI_CLASS and label not in OI_TABLE:
                    continue
                image = p[0]
                labels[image].add(label)
                if p[11] == '1':
                    drawn.add(image)   # a drawing or a toy, not food
                if label in OI_CLASS:
                    boxes[image].append((OI_CLASS[label], float(p[4]),
                                         float(p[6]), float(p[5]), float(p[7])))
        per_class = defaultdict(list)
        for image, found in boxes.items():
            main = Counter(c for c, *_ in found).most_common(1)[0][0]
            if (image in drawn or len(found) > OI_MAX_BOXES or not labels[image] &
                    (OI_DISH if main in OI_ON_DISH else OI_TABLE)):
                continue
            per_class[main].append(image)
        chosen = []
        for code in sorted(per_class):
            images = sorted(per_class[code])
            random.shuffle(images)
            chosen += images[:OI_PER_CLASS]
            stage(f'Open Images {split}: {code} on {len(images)} table photos, '
                  f'{min(len(images), OI_PER_CLASS)} taken')

        def fetch(image):
            path = os.path.join(OI_DIR, split, image + '.jpg')
            if not os.path.exists(path):
                try:
                    urllib.request.urlretrieve(OI_PHOTO.format(split=split, id=image),
                                               path + '.part')
                    os.replace(path + '.part', path)
                except Exception:
                    return None
            return path

        os.makedirs(os.path.join(OI_DIR, split), exist_ok=True)
        with ThreadPoolExecutor(32) as pool:
            for image, path in zip(chosen, pool.map(fetch, chosen)):
                if path:
                    oi_photos.append((path, boxes[image]))
    stage(f'Open Images: {len(oi_photos)} photos')

# %% [markdown]
# ## Box them
# Grounding DINO finds the dish's foods, the plate detector checks them.
# Photos with no box left are dropped. Everything is written to
# `WORK_DIR/out/{images,labels}/train`.

# %%
import numpy as np
import torch
from PIL import Image, ImageDraw, ImageOps
from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
from ultralytics import YOLO

DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'
stage(f'Loading {GD_MODEL} on {DEVICE} ...')
gd_processor = AutoProcessor.from_pretrained(GD_MODEL)
gd_model = AutoModelForZeroShotObjectDetection.from_pretrained(GD_MODEL).to(DEVICE).eval()
teacher = YOLO(TEACHER)
assert [teacher.names[i] for i in range(len(teacher.names))] == CLASSES, \
    'TEACHER_FROM is not a detector with the 21 contract classes'


def area(b):
    return max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])


def iou(a, b):
    inter = area((max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])))
    union = area(a) + area(b) - inter
    return inter / union if union > 0 else 0.0


def phrase_class(label, prompts):
    """The prompt a Grounding DINO label stands for. It sometimes joins two
    prompts ("fried egg egg"); a label that fits two equally well is
    dropped."""
    words = set(label.split())
    if not words:
        return None
    fits = sorted(((len(words & set(p.split())) /
                    min(len(words), len(p.split())), p) for p in prompts),
                  reverse=True)
    best = {prompts[p] for fit, p in fits if fit == fits[0][0]}
    if fits[0][0] < 0.5 or len(best) > 1:
        return None
    return best.pop()


def grounding(im, prompts):
    """[(class, score, box)] with boxes as shares of the photo."""
    inputs = gd_processor(images=im, text='. '.join(prompts) + '.',
                          return_tensors='pt').to(DEVICE)
    with torch.no_grad(), torch.autocast(DEVICE, enabled=DEVICE == 'cuda'):
        out = gd_model(**inputs)
    try:
        result = gd_processor.post_process_grounded_object_detection(
            out, inputs.input_ids, threshold=BOX_MIN, text_threshold=TEXT_MIN,
            target_sizes=[(im.height, im.width)])[0]
    except TypeError:   # transformers before 4.51
        result = gd_processor.post_process_grounded_object_detection(
            out, inputs.input_ids, box_threshold=BOX_MIN,
            text_threshold=TEXT_MIN, target_sizes=[(im.height, im.width)])[0]
    labels = result['text_labels'] if 'text_labels' in result else result['labels']
    found = []
    for box, score, label in zip(result['boxes'].float().tolist(),
                                 result['scores'].float().tolist(), labels):
        code = phrase_class(label, prompts)
        if code:
            found.append((code, score, (box[0] / im.width, box[1] / im.height,
                                        box[2] / im.width, box[3] / im.height)))
    return found


def detector(im):
    r = teacher.predict(im, imgsz=640, conf=TEACHER_AGREE, iou=0.5,
                        device=0 if DEVICE == 'cuda' else 'cpu', verbose=False)[0]
    return [(CLASSES[int(c)], float(s), tuple(b))
            for c, s, b in zip(r.boxes.cls.tolist(), r.boxes.conf.tolist(),
                               r.boxes.xyxyn.tolist())]


def merge(gd, seen, meats):
    """The boxes to keep: (class, score, box). [meats]: the dish's meat
    classes; a detector meat box of another kind is left out."""
    kept = []
    for code, score, box in sorted(gd, key=lambda d: -d[1]):
        if area(box) > (0.95 if code in WHOLE else MAX_AREA):
            continue
        if score < BOX_SURE and not any(iou(box, b) >= 0.5 for _, _, b in seen):
            continue
        # One class per place, the more likely one.
        if any(iou(box, b) > (0.5 if c == code else 0.7) for c, _, b in kept):
            continue
        kept.append((code, score, box))
    # A box around several others is a group (the whole bowl), not a food.
    def inside(b, outer):
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        return outer[0] <= cx <= outer[2] and outer[1] <= cy <= outer[3]
    kept = [d for d in kept if d[0] in WHOLE or area(d[2]) < 0.25 or
            sum(inside(o[2], d[2]) for o in kept if o is not d) < 2]
    for code, score, box in seen:
        if score < TEACHER_SURE or any(iou(box, b) >= 0.3 for _, _, b in kept):
            continue
        if code in MEATS and meats:
            if len(meats) > 1 and code not in meats:
                continue
            code = code if code in meats else next(iter(meats))
        kept.append((code, score, box))
    return kept


OUT_DIR = os.path.join(WORK_DIR, 'out')
shutil.rmtree(OUT_DIR, ignore_errors=True)
for kind in ('images', 'labels'):
    os.makedirs(os.path.join(OUT_DIR, kind, 'train'), exist_ok=True)


def shrunk(path):
    """The photo turned as the camera meant and shrunk, or None."""
    try:
        with Image.open(path) as im:
            im = ImageOps.exif_transpose(im).convert('RGB')
            im.thumbnail((LONG_SIDE, LONG_SIDE))
            return im
    except Exception:
        return None


def save(name, im, boxes):
    im.save(os.path.join(OUT_DIR, 'images', 'train', name + '.jpg'), quality=90)
    with open(os.path.join(OUT_DIR, 'labels', 'train', name + '.txt'), 'w') as f:
        for code, _, (left, top, right, bottom) in boxes:
            left, top = max(0.0, left), max(0.0, top)
            right, bottom = min(1.0, right), min(1.0, bottom)
            if right - left > 0.005 and bottom - top > 0.005:
                f.write(f'{CLASS_INDEX[code]} {(left + right) / 2:.6f} '
                        f'{(top + bottom) / 2:.6f} {right - left:.6f} '
                        f'{bottom - top:.6f}\n')


rows = []            # sources.csv: name, source, dish, original photo
boxes_per_class = Counter()
kept_per_dish, seen_per_dish = Counter(), Counter()
dropped = Counter()
samples = []         # (name, boxes) for the preview
work = [('dish', dish, path, None) for dish, path in dish_photos] + \
       [('oi', '', path, found) for path, found in oi_photos]
started = time.time()


def read_ahead(jobs, ahead=32):
    """(job, photo) pairs, the next photos read and shrunk while the GPU boxes
    this one. Only [ahead] are held at a time: all 15,000 would not fit in
    Colab's memory."""
    from collections import deque
    with ThreadPoolExecutor(4) as pool:
        pending = deque()
        for job in jobs:
            pending.append((job, pool.submit(shrunk, job[2])))
            if len(pending) >= ahead:
                job, future = pending.popleft()
                yield job, future.result()
        while pending:
            job, future = pending.popleft()
            yield job, future.result()


for done, (job, im) in enumerate(read_ahead(work)):
    kind, dish, path, oi_boxes = job
    if im is None:
        dropped['unreadable photo'] += 1
        continue
    if kind == 'dish':
        seen_per_dish[dish] += 1
        prompts = PROMPTS[dish]
        boxes = merge(grounding(im, prompts), detector(im),
                      {c for c in prompts.values() if c in MEATS})
        if not boxes:
            dropped['dish photo: no food found'] += 1
            continue
        kept_per_dish[dish] += 1
    else:
        boxes = [(code, 1.0, box) for code, *box in oi_boxes]
        unsure = [d for d in grounding(im, OI_UNSURE) if d[1] >= UNSURE_SCORE]
        if any(all(iou(d[2], b) < 0.5 for _, _, b in boxes) for d in unsure):
            dropped['open images: unboxed rice, noodles or meat'] += 1
            continue
        for code, score, box in detector(im):
            if score >= TEACHER_SURE and code not in MEATS | {'com', 'bun', 'mi'} \
                    and all(iou(box, b) < 0.3 for _, _, b in boxes):
                boxes.append((code, score, box))
    name = f'{"auto" if kind == "dish" else "oi"}_{len(rows):06d}'
    save(name, im, boxes)
    rows.append((name, kind, dish, os.path.relpath(path, WORK_DIR)
                 if kind == 'oi' else os.path.relpath(path, INPUT_ROOT)))
    boxes_per_class.update(code for code, *_ in boxes)
    # A random 400 of the kept photos, for the preview.
    if len(samples) < 400:
        samples.append((name, boxes))
    elif random.randrange(len(rows)) < 400:
        samples[random.randrange(400)] = (name, boxes)
    if done % 500 == 499:
        rate = (time.time() - started) / (done + 1)
        stage(f'{done + 1} of {len(work)} photos ({rate:.2f} s each, '
              f'{rate * (len(work) - done - 1) / 60:.0f} min left)')
stage(f'Kept {len(rows)} photos | dropped: {dict(dropped)}')

# %% [markdown]
# ## Save: the zip, a card, a preview

# %%
import zipfile
from datetime import date

with open(os.path.join(OUT_DIR, 'sources.csv'), 'w', newline='',
          encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['name', 'source', 'dish', 'photo'])
    writer.writerows(rows)
ZIP = os.path.join(OUTPUT_DIR, 'autolabel.zip')
with zipfile.ZipFile(ZIP + '.part', 'w', zipfile.ZIP_STORED) as z:
    for folder, _, names in os.walk(OUT_DIR):
        for name in names:
            path = os.path.join(folder, name)
            z.write(path, os.path.relpath(path, OUT_DIR))
os.replace(ZIP + '.part', ZIP)

random.shuffle(samples)
tiles = []
for name, boxes in samples[:PREVIEW]:
    im = Image.open(os.path.join(OUT_DIR, 'images', 'train', name + '.jpg'))
    im.thumbnail((320, 320))
    draw = ImageDraw.Draw(im)
    for code, score, (left, top, right, bottom) in boxes:
        draw.rectangle((left * im.width, top * im.height, right * im.width,
                        bottom * im.height), outline=(255, 40, 40), width=2)
        draw.text((left * im.width + 3, top * im.height + 2), code,
                  fill=(255, 255, 0))
    tiles.append(im)
if tiles:
    grid = Image.new('RGB', (6 * 320, (len(tiles) + 5) // 6 * 320), 'white')
    for i, tile in enumerate(tiles):
        grid.paste(tile, (i % 6 * 320, i // 6 * 320))
    grid.save(os.path.join(OUTPUT_DIR, 'preview.jpg'), quality=85)

lines = [
    '# Autolabel card', '',
    f'- Made: {date.today().isoformat()}, {GD_MODEL} checked by {TEACHER_FROM}'
    + (', QUICK TEST' if QUICK_TEST else ''),
    f'- Thresholds: Grounding DINO {BOX_MIN}–{BOX_SURE}, detector agree '
    f'{TEACHER_AGREE}, sure {TEACHER_SURE}',
    f'- Photos kept: {len(rows)} ({sum(kept_per_dish.values())} dish photos, '
    f'{sum(1 for r in rows if r[1] == "oi")} Open Images)',
    f'- Dropped: {dict(dropped)}',
    f'- Time: {(time.time() - NOTEBOOK_STARTED) / 60:.0f} min', '',
    '| dish | photos | kept |', '|---|---|---|',
]
lines += [f'| {d} | {seen_per_dish[d]} | {kept_per_dish[d]} |'
          for d in sorted(seen_per_dish)]
lines += ['', '| class | boxes |', '|---|---|']
lines += [f'| {c} | {boxes_per_class[c]} |' for c in CLASSES]
card = '\n'.join(lines) + '\n'
with open(os.path.join(OUTPUT_DIR, 'AUTOLABEL_CARD.md'), 'w', encoding='utf-8') as f:
    f.write(card)
print(card)
stage(f'Done: {ZIP} ({os.path.getsize(ZIP) / 1e6:.0f} MB). Next: '
      'train_detector.ipynb with the same Google account.')
