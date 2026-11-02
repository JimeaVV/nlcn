# %% [markdown]
# # MacroRunner – train the plate detector (YOLO)
#
# Trains the second model of `docs/MODEL_CONTRACT.md` (contract 1.7, §7): a
# YOLO11s at 512 px that finds each food on a plate with a box, so a plate of plain
# rice and chicken breast comes out as "com" and "ga" instead of the dish
# the classifier knows best. 21 classes, each one an app component or a
# group of variants. The result is the three files the app reads from
# `assets/models/`: `detector.tflite`, `detector_classes.txt` and
# `DETECTOR_CARD.md`.
#
# Data: the boxes VietFood67 already has, MyFood's masks turned into boxes,
# and FoodInsSeg's boxes around each piece of food (sliced pork, chicken,
# tofu on rice), with touching pieces of one food joined into one box
# (`JOIN_GAP`). Each keeps its own train/val/test split. Also, if found,
# `autolabel.zip` from `autolabel_detector.ipynb`: Vietnamese dish photos
# boxed by Grounding DINO, and Open Images boxes. Those are machine-made, so
# they go to train only, and val and test stay comparable between runs.
# `plates.zip` from `make_plates_data.py` goes to train only too: plates
# with chicken, pork, beef and greens from MyFoodRepo (boxes from its hand-drawn
# outlines) and Nutrition5k (boxed by Grounding DINO), the classes the
# detector missed most on the cơm phần photos.
#
# **On Google Colab**
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. The Kaggle key in *Secrets* (the key icon on the left), as for the food
#    model: `KAGGLE_API_TOKEN` with the `KGAT_...` value, notebook access on.
# 3. *Runtime → Run all*, then allow Google Drive in the window that opens
#    within the first seconds. VietFood67 downloads once per session (26 GB,
#    about 15 minutes). Results go to Google Drive, folder
#    `macrorunner_train/detector_yolo11s`. Run `autolabel_detector.ipynb`
#    first with the same Google account: this notebook then finds
#    `macrorunner_train/detector_autolabel/autolabel.zip` by itself. From
#    another account, put a share link to that zip in `AUTOLABEL_FROM`.
# 4. Run once with `QUICK_TEST = True` (about 25 minutes, most of it the
#    download), then set `QUICK_TEST = False` and run all again in the same
#    session, so nothing downloads twice.
# 5. Free Colab ends a session after about 5 hours. At `TIME_LIMIT_HOURS`
#    training stops by itself after an epoch, and the notebook still tests
#    and exports the best epoch so far. Then, or if the session was cut off
#    anyway, run all again with the same settings: training continues from
#    `last.pt` in Drive.
# 6. To go on with another Google account: in the first account's Drive,
#    share `macrorunner_train/detector_yolo11s/train/weights` as *Anyone
#    with the link*, put that link in `RESUME_FROM` and run all with the
#    other account. It copies `last.pt` and `best.pt` into its own Drive
#    first.
# 7. To make a finished model better instead of training from scratch: put
#    a shared link to its `export/detector_best.pt` in `FINETUNE_FROM`. The
#    run starts from those weights with a lower learning rate for
#    `FINETUNE_EPOCHS` epochs, and saves to its own folder
#    `detector_finetune`, so the earlier run stays as it was. Set `IMGSZ` to
#    the size that model was trained at (640 for the YOLO11n). Steps
#    5 and 6 work the same for it.
#
# **On Kaggle**
# 1. Add the dataset `thomasnguyen6868/vietfood68`. For the boxed dish
#    photos, put a share link to `autolabel.zip` in `AUTOLABEL_FROM`, or add
#    a dataset that holds it. Add the private dataset that holds
#    `plates.zip` too (or a link in `PLATES_FROM`).
# 2. *Accelerator*: GPU T4 x2 (training uses one) or P100. Turn Internet on:
#    MyFood downloads from Zenodo, FoodInsSeg and `autolabel.zip` from Google
#    Drive.
# 3. *Save Version → Save & Run All (Commit)*. The files are in the
#    *Output* tab. At 11 hours training stops by itself and exports the best
#    epoch so far.
# 4. To go on from there: add that version's output to the notebook
#    (*Add Input → Your Work*), set `RESUME_FROM = '/kaggle/input'` and save a
#    new version. A Colab run's shared `train/weights` link works there too.
#    If that output cannot be added (a version that ended in an error), put
#    its `last.pt` and `best.pt` in a new private dataset (*Upload → New
#    Dataset*) and add that instead.
#
# Time on Kaggle (run of 2026-10-29): about 5 minutes an epoch, so the 35
# epochs took 3 hours. Reading the VietFood67 labels one file at a time
# took 158 minutes before that; they are now read 64 at a time. On free
# Colab, expect two sessions (step 5). The 40-epoch run of 2026-10-27
# stopped getting better on val after epoch 30.
#
# Ultralytics is AGPL-3.0; VietFood67 and FoodInsSeg are CC BY-NC-SA 4.0;
# MyFood, MyFoodRepo (Food Recognition 2022) and Nutrition5k are CC BY 4.0.

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
# COCO weights to start from. YOLO11s finds more than YOLO11n (COCO mAP50-95
# 47.0 against 39.5) at about three times the work; 512 px instead of 640
# keeps it near the phone's 400 ms.
MODEL = os.environ.get('MODEL', 'yolo11s.pt')
IMGSZ = 320 if QUICK_TEST else 512
# The learning rate falls to its lowest over all EPOCHS and the last 10 go
# without mosaic, so a run cut off halfway ends worse than a shorter one
# run to the end: set this to what there is time for.
EPOCHS = 2 if QUICK_TEST else 35
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
# FoodInsSeg and MyFood box every slice of cucumber and every chip, where
# VietFood67 boxes the whole heap, and the app only shows which foods are
# there. Boxes of one class that overlap or are closer than this share of
# the photo are joined into one, except foods the app counts by their boxes.
JOIN_GAP = 0.02
# FoodInsSeg is the only set of rice plates with several foods, the photo
# the app sees most, but 3,374 of 29,284 train photos: each is used this
# many times in train.
FIS_REPEAT = 3
LONG_SIDE = 640          # photos are shrunk to this once, for fast loading
ULTRALYTICS_VERSION = '8.4.185'
# A shared link to another Colab account's `train/weights` folder, to train
# on from its last.pt (step 6 above), or a folder here holding one (Kaggle
# step 4). Empty: start or go on in this Drive.
RESUME_FROM = os.environ.get('RESUME_FROM', '')
# A shared link to a finished run's `export/detector_best.pt` (or a path to
# it, or a folder here with one best.pt or detector_best.pt under it, such as
# an added Kaggle dataset of the weights), to fine-tune from (step 7 above).
# Empty: start from the COCO weights.
FINETUNE_FROM = os.environ.get('FINETUNE_FROM', '')
FINETUNE_EPOCHS = 30
# `autolabel.zip` from autolabel_detector.ipynb: a path or a shared link.
# Empty: look for it in this Drive (Colab) or the inputs (Kaggle).
AUTOLABEL_FROM = os.environ.get('AUTOLABEL_FROM', '')
# `plates.zip` from make_plates_data.py, found the same way.
PLATES_FROM = os.environ.get('PLATES_FROM', '')
# Its photos are used this many times in train: about 2,200 plates against
# 34,000 photos, and chicken on cơm phần was the detector's worst miss.
PLATES_REPEAT = 2
# Where a plates.zip of labels only finds its photos: the MyFoodRepo folder
# of the Kaggle dataset awsaf49/food-recognition-2022-dataset, and
# Nutrition5k on Hugging Face.
FR22_FOLDER = 'public_training_set_release_2.0'
N5K_PHOTO = os.environ.get(
    'N5K_PHOTO', 'https://huggingface.co/datasets/ai5labsOfficial/nutrition5k/'
    'resolve/main/images/{}.png')
# lr0 for fine-tuning, a fifth of the 0.01 that SGD starts a fresh run with,
# so it learns the new photos without forgetting the old ones.
FINETUNE_LR = 0.002
if FINETUNE_FROM and not QUICK_TEST:
    EPOCHS = FINETUNE_EPOCHS

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
# FoodInsSeg on the authors' Google Drive (1.3 GB zip).
FOODINSSEG_ID = '1Wa8_j4flJOMM6a2QGpiPga0r1GC__Rg2'
DOWNLOAD_FOODINSSEG = os.environ.get('DOWNLOAD_FOODINSSEG', '1') == '1'
COLAB_ROOT = os.environ.get('COLAB_ROOT', '/content')

# %% [markdown]
# ## Setup: Ultralytics, Drive, the datasets

# %%
import re
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
                              # Fine-tuning keeps the size of the model it
                              # starts from, which MODEL does not say.
                              'detector_' + ('finetune' if FINETUNE_FROM else
                                             os.path.splitext(os.path.basename(MODEL))[0])
                              + ('_quick' if QUICK_TEST else ''))
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



def load_gdown():
    try:
        import gdown
    except ImportError:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'gdown'],
                       check=True)
        import gdown
    return gdown


weights_dir = os.path.join(OUTPUT_DIR, 'train', 'weights')
if RESUME_FROM and not os.path.exists(os.path.join(weights_dir, 'last.pt')):
    stage(f'Copying last.pt and best.pt from {RESUME_FROM} ...')
    try:
        if os.path.exists(RESUME_FROM):
            # A folder here, e.g. /kaggle/input with the last version's
            # output or a dataset of the weights added: the one weights
            # folder somewhere under it. Photo and label folders are not
            # searched: walking VietFood67's took 3.5 minutes.
            folders = []
            for folder, dirs, files in os.walk(RESUME_FROM, followlinks=True):
                dirs[:] = [d for d in dirs if d not in ('images', 'labels')]
                if 'last.pt' in files and 'best.pt' in files:
                    folders.append(folder)
            if len(folders) != 1:
                seen = sorted(os.path.join(top, d) for top in
                              [RESUME_FROM] + [os.path.join(RESUME_FROM, d)
                                               for d in os.listdir(RESUME_FROM)]
                              if os.path.isdir(top) for d in os.listdir(top))
                raise ValueError(f'{len(folders)} folders with last.pt and '
                                 f'best.pt: {folders}. In {RESUME_FROM}: {seen}')
            got = [os.path.join(folders[0], n) for n in ('last.pt', 'best.pt')]
        else:
            got = load_gdown().download_folder(
                url=RESUME_FROM, output=os.path.join(WORK_DIR, 'resume_from'),
                quiet=True)
        os.makedirs(weights_dir, exist_ok=True)
        for name in ('last.pt', 'best.pt'):
            path = next(p for p in got or [] if os.path.basename(p) == name)
            shutil.copy(path, weights_dir)
    except Exception as error:
        raise RuntimeError(
            f'Could not copy the weights from RESUME_FROM: {error!r}. Share the '
            'train/weights folder as "Anyone with the link", or on Kaggle add '
            'only the one earlier output that holds it.') from error



def is_checkpoint(path):
    """True for a file torch.save wrote (a zip). A sharing link that is not
    public, or an old gdown given a /view link, saves the web page instead."""
    with open(path, 'rb') as f:
        return f.read(2) == b'PK'


if FINETUNE_FROM and os.path.isdir(FINETUNE_FROM):
    found = []
    for folder, dirs, files in os.walk(FINETUNE_FROM, followlinks=True):
        dirs[:] = [d for d in dirs if d not in ('images', 'labels')]
        found += [os.path.join(folder, n) for n in ('best.pt', 'detector_best.pt')
                  if n in files]
    if len(found) != 1:
        raise RuntimeError(f'FINETUNE_FROM: {len(found)} best.pt or '
                           f'detector_best.pt under {FINETUNE_FROM}: {found}')
    FINETUNE_FROM = found[0]
if FINETUNE_FROM:
    if os.path.exists(FINETUNE_FROM):
        MODEL = FINETUNE_FROM
    else:
        MODEL = os.path.join(WORK_DIR, 'finetune_from.pt')
        if not os.path.exists(MODEL) or not is_checkpoint(MODEL):
            stage(f'Copying the weights to fine-tune from {FINETUNE_FROM} ...')
            # The file id, not the link: Colab's gdown downloads the page
            # behind a .../file/d/<id>/view link.
            match = re.search(r'/d/([\w-]{20,})|[?&]id=([\w-]{20,})',
                              FINETUNE_FROM)
            file_id = next(g for g in match.groups() if g) if match else ''
            try:
                load_gdown().download(id=file_id or FINETUNE_FROM,
                                      output=MODEL + '.part', quiet=True)
                if not is_checkpoint(MODEL + '.part'):
                    raise ValueError('got a web page, not detector_best.pt')
                os.replace(MODEL + '.part', MODEL)
            except Exception as error:
                raise RuntimeError(
                    f'Could not copy FINETUNE_FROM: {error!r}. Share '
                    'detector_best.pt as "Anyone with the link".') from error

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

foodinsseg_dir = os.path.join(EXTRA_ROOT, 'foodinsseg')
if DOWNLOAD_FOODINSSEG and not os.path.isdir(foodinsseg_dir):
    import zipfile
    stage('Downloading FoodInsSeg (1.3 GB) ...')
    try:
        load_gdown().download(id=FOODINSSEG_ID, output=foodinsseg_dir + '.zip',
                              quiet=True)
        with zipfile.ZipFile(foodinsseg_dir + '.zip') as z:
            z.extractall(foodinsseg_dir + '.part')
        os.replace(foodinsseg_dir + '.part', foodinsseg_dir)
        os.remove(foodinsseg_dir + '.zip')
    except Exception as error:
        # Google Drive refuses a file many people downloaded that day.
        raise RuntimeError(
            f'Could not download FoodInsSeg: {error!r}. Try again later, or set '
            'DOWNLOAD_FOODINSSEG to 0 to train without it.') from error

zips_in_input = {}
plates_unzipped = ''   # Kaggle unzips a zip uploaded as a dataset
if not (AUTOLABEL_FROM and PLATES_FROM):
    # Photo and label folders are not searched: walking VietFood67's took
    # 3.5 minutes on Kaggle.
    for folder, dirs, files in os.walk(INPUT_ROOT, followlinks=True):
        if 'PLATES_CARD.md' in files and 'labels' in dirs:
            plates_unzipped = plates_unzipped or folder
        dirs[:] = [d for d in dirs if d not in ('images', 'labels')]
        for name in ('autolabel.zip', 'plates.zip'):
            if name in files:
                zips_in_input.setdefault(name, os.path.join(folder, name))


def unzip_extra(name, given, drive_folder):
    """Unzips `name` into EXTRA_ROOT: [given] (a path or a shared link), else
    the one in this Drive's [drive_folder] (Colab) or in the inputs."""
    target = os.path.join(EXTRA_ROOT, os.path.splitext(name)[0])
    if os.path.isdir(target):
        return
    path = given
    if not path:
        places = [zips_in_input.get(name, '')]
        if ON_COLAB:
            places.insert(0, os.path.join(COLAB_ROOT, 'drive', 'MyDrive',
                                          'macrorunner_train', drive_folder,
                                          name))
        path = next((p for p in places if p and os.path.exists(p)), '')
    if not path:
        return
    import zipfile
    if not os.path.exists(path):
        stage(f'Copying {name} from {path} ...')
        match = re.search(r'/d/([\w-]{20,})|[?&]id=([\w-]{20,})', path)
        file_id = next(g for g in match.groups() if g) if match else path
        path = os.path.join(WORK_DIR, name)
        load_gdown().download(id=file_id, output=path, quiet=True)
    stage(f'Unzipping {path} ...')
    with zipfile.ZipFile(path) as z:
        z.extractall(target + '.part')
    os.replace(target + '.part', target)


unzip_extra('autolabel.zip', AUTOLABEL_FROM, 'detector_autolabel')
if not os.path.isdir(os.path.join(EXTRA_ROOT, 'autolabel')):
    print('No autolabel.zip: training without the boxed dish photos. Run '
          'autolabel_detector.ipynb first, or set AUTOLABEL_FROM.', flush=True)
unzip_extra('plates.zip', PLATES_FROM, 'detector_plates')
PLATES_DIR = os.path.join(EXTRA_ROOT, 'plates')
if not os.path.isdir(PLATES_DIR) and plates_unzipped:
    PLATES_DIR = plates_unzipped
if not os.path.isdir(PLATES_DIR):
    print('No plates.zip: training without the extra chicken, pork, beef and '
          'greens plates. Add its dataset, or set PLATES_FROM.', flush=True)
stage(f'Photos from {INPUT_ROOT} and {EXTRA_ROOT} | results to {OUTPUT_DIR}')

# %% [markdown]
# ## Contract
# Class codes in output order (contract 1.7, §7.1). They must match
# `detector_classes.txt`, which this notebook writes at the end.

# %%
CONTRACT_VERSION = '1.7'
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
# FoodInsSeg: category name → class.
FIS_CLASS = {
    'rice': 'com', 'pork': 'heo', 'chicken duck': 'ga', 'steak': 'bo',
    'fish': 'ca', 'shrimp': 'tom', 'egg': 'trung', 'tofu': 'dau_hu',
    'french fries': 'khoai_tay_chien', 'cucumber': 'dua_leo_ca_chua',
    'tomato': 'dua_leo_ca_chua', 'lettuce': 'rau', 'broccoli': 'rau',
    'cabbage': 'rau', 'bean sprouts': 'rau', 'rape': 'rau',
}
# Foods that may look like one of ours without being labelled as it (bread
# as bánh mì, noodles as bún or mì, wontons as chả giò). Photos with them
# are left out, so the model is not taught that they are background.
FIS_UNSURE = {
    'bread', 'noodles', 'pasta', 'soup', 'fried meat', 'sausage',
    'wonton dumplings', 'hanamaki baozi', 'hamburg', 'salad',
    'other ingredients',
}

# %% [markdown]
# ## Build the YOLO dataset
# Each photo is shrunk once and written with its remapped boxes to
# `WORK_DIR/yolo/{images,labels}/{train,val,test}`.

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
YOLO_DIR = os.path.join(WORK_DIR, 'yolo')
random.seed(SEED)
skipped = Counter()


# The app counts eggs, spring rolls and bánh mì by their boxes (contract
# §7.3), so those are never joined.
COUNTED_CLASSES = {CLASS_INDEX[c] for c in ('trung', 'cha_gio', 'banh_mi_o')}
joined = Counter()


def join_pieces(boxes):
    """Boxes (class, cx, cy, w, h) with those of one class that overlap or
    lie within JOIN_GAP of each other replaced by one box around them."""
    corners = [(c, cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
               for c, cx, cy, w, h in boxes]
    group = list(range(len(corners)))

    def root(i):
        while group[i] != i:
            group[i] = group[group[i]]
            i = group[i]
        return i

    for i, a in enumerate(corners):
        for j in range(i + 1, len(corners)):
            b = corners[j]
            if (a[0] == b[0] and a[0] not in COUNTED_CLASSES and
                    a[1] - JOIN_GAP <= b[3] and b[1] - JOIN_GAP <= a[3] and
                    a[2] - JOIN_GAP <= b[4] and b[2] - JOIN_GAP <= a[4]):
                group[root(i)] = root(j)
    out = {}
    for i, (c, left, top, right, bottom) in enumerate(corners):
        r = root(i)
        if r in out:
            _, l0, t0, r0, b0 = out[r]
            out[r] = (c, min(l0, left), min(t0, top), max(r0, right),
                      max(b0, bottom))
        else:
            out[r] = (c, left, top, right, bottom)
    joined['before'] += len(boxes)
    joined['after'] += len(out)
    return [(c, (l + r) / 2, (t + b) / 2, r - l, b - t)
            for c, l, t, r, b in out.values()]


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
    labels = []
    for folder, _, names in os.walk(os.path.join(root, 'labels'),
                                    followlinks=True):
        for name in sorted(names):
            if not name.endswith('.txt'):
                continue
            path = os.path.join(folder, name)
            rel = os.path.splitext(
                os.path.relpath(path, os.path.join(root, 'labels')))[0]
            if rel in images:
                labels.append((path, rel))
            else:
                skipped['vf67: no image'] += 1

    def read(path):
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
                    boxes.append((CLASS_INDEX[VF_CLASS[vf_name]], cx, cy, w, h))
        return boxes, names_seen

    # Kaggle fetches each file of a dataset the first time it is read, so
    # one after another the 171,619 label files took 158 minutes.
    kept, background = [], []
    with ThreadPoolExecutor(64) as pool:
        for (path, rel), (boxes, names_seen) in zip(
                labels, pool.map(read, (path for path, _ in labels))):
            if names_seen & VF_DISH_BOXES and not KEEP_DISH_PHOTOS:
                skipped['vf67: whole-dish box'] += 1
                continue
            item = (images[rel], split_of(rel), boxes)
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
                items.append((os.path.join(folder, name), split,
                              join_pieces(boxes)))
    stage(f'MyFood: {len(items)} photos with boxes')
    return items


def foodinsseg_items(root):
    """FoodInsSeg's COCO boxes. Its test photos are halved into val and
    test."""
    kept, background = [], []
    for json_name, folder in (('Train.json', 'train'), ('Test.json', 'test')):
        with open(os.path.join(root, 'annotations', json_name)) as f:
            coco = json.load(f)
        names = {c['id']: c['name'] for c in coco['categories']}
        unknown = (set(FIS_CLASS) | FIS_UNSURE) - set(names.values())
        assert not unknown, f'FoodInsSeg has no category {unknown}'
        per_image = {}
        for a in coco['annotations']:
            per_image.setdefault(a['image_id'], []).append(a)
        for image in coco['images']:
            found = per_image.get(image['id'], [])
            if any(names[a['category_id']] in FIS_UNSURE for a in found):
                skipped['foodinsseg: unsure food'] += 1
                continue
            width, height = image['width'], image['height']
            boxes = []
            for a in found:
                code = FIS_CLASS.get(names[a['category_id']])
                left, top, w, h = a['bbox']
                if code and w > 0 and h > 0:
                    boxes.append((CLASS_INDEX[code], (left + w / 2) / width,
                                  (top + h / 2) / height, w / width,
                                  h / height))
            split = ('train' if folder == 'train' else
                     'val' if image['id'] % 2 == 0 else 'test')
            item = (os.path.join(root, 'images', folder, image['file_name']),
                    split, join_pieces(boxes))
            (kept if boxes else background).append(item)
    random.shuffle(background)
    background = background[:int(BACKGROUND_SHARE * len(kept))]
    stage(f'FoodInsSeg: {len(kept)} photos with boxes, {len(background)} '
          'background')
    return kept + background


def autolabel_items(root):
    """autolabel_detector.ipynb's boxes, for train only. The photos are
    already shrunk."""
    items = []
    labels = os.path.join(root, 'labels', 'train')
    for name in sorted(os.listdir(labels)):
        stem = os.path.splitext(name)[0]
        boxes = []
        with open(os.path.join(labels, name)) as f:
            for line in f:
                c, cx, cy, w, h = line.split()
                boxes.append((int(c), float(cx), float(cy), float(w), float(h)))
        if boxes:
            items.append((stem.split('_')[0], os.path.join(
                root, 'images', 'train', stem + '.jpg'), 'train', boxes))
    stage(f'Autolabel: {sum(i[0] == "auto" for i in items)} dish photos, '
          f'{sum(i[0] == "oi" for i in items)} Open Images photos')
    return items


def plates_photos(root):
    """{name: photo path} for a plates.zip of labels only (photos are too big
    to upload from a browser): MyFoodRepo's from the Kaggle dataset
    awsaf49/food-recognition-2022-dataset among the inputs, Nutrition5k's
    downloaded from Hugging Face. The boxes fit the photos as stored."""
    import csv
    import urllib.request
    with open(os.path.join(root, 'sources.csv'), newline='',
              encoding='utf-8') as f:
        rows = [r for r in csv.DictReader(f)
                if not os.path.exists(os.path.join(root, 'images', 'train',
                                                   r['name'] + '.jpg'))]
    photos = {}
    if any(r['source'] == 'fr22' for r in rows):
        fr22 = None
        for folder, dirs, _ in os.walk(INPUT_ROOT, followlinks=True):
            if os.path.basename(folder) == FR22_FOLDER:
                fr22 = os.path.join(folder, 'images')
                break
            dirs[:] = [d for d in dirs if d not in ('images', 'labels')]
        if not fr22:
            raise RuntimeError(f'plates.zip holds MyFoodRepo boxes but no '
                               f'{FR22_FOLDER} folder is in the inputs: add '
                               'awsaf49/food-recognition-2022-dataset.')
        photos.update((r['name'], os.path.join(fr22, r['photo']))
                      for r in rows if r['source'] == 'fr22')
    n5k = os.path.join(EXTRA_ROOT, 'nutrition5k')
    os.makedirs(n5k, exist_ok=True)

    def fetch(row):
        path = os.path.join(n5k, row['photo'] + '.png')
        for _ in range(3):
            if os.path.exists(path):
                return row['name'], path
            try:
                urllib.request.urlretrieve(N5K_PHOTO.format(row['photo']),
                                           path + '.part')
                os.replace(path + '.part', path)
            except Exception:
                time.sleep(2)
        return row['name'], None

    wanted = [r for r in rows if r['source'] == 'n5k']
    if wanted:
        stage(f'Downloading {len(wanted)} Nutrition5k photos ...')
        with ThreadPoolExecutor(32) as pool:
            got = dict(pool.map(fetch, wanted))
        missing = [n for n, p in got.items() if not p]
        if missing:
            print(f'  {len(missing)} Nutrition5k photos could not be '
                  'downloaded: left out.', flush=True)
        photos.update((n, p) for n, p in got.items() if p)
    return photos


def plates_items(root):
    """make_plates_data.py's boxes, for train only, named after their source
    (fr22_…, n5k_…). MyFoodRepo outlines one heap of greens in pieces, so
    touching pieces are joined as for FoodInsSeg."""
    items = []
    labels = os.path.join(root, 'labels', 'train')
    photos = plates_photos(root)
    for name in sorted(os.listdir(labels)):
        stem = os.path.splitext(name)[0]
        image = photos.get(stem, os.path.join(root, 'images', 'train',
                                              stem + '.jpg'))
        if not os.path.exists(image):
            skipped['plates: no photo'] += 1
            continue
        boxes = []
        with open(os.path.join(labels, name)) as f:
            for line in f:
                c, cx, cy, w, h = line.split()
                boxes.append((int(c), float(cx), float(cy), float(w), float(h)))
        items.append((stem.split('_')[0], image, 'train', join_pieces(boxes)))
    stage('Plates: ' + ', '.join(f'{n} {s}' for s, n in sorted(
        Counter(i[0] for i in items).items())) + ' photos')
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
for root in find_roots(INPUT_ROOT, lambda folder, files:
                       is_detection_root(folder) and 'PLATES_CARD.md' not in files):
    items += [('vf67', *item) for item in vf67_items(root)]
for root in find_roots(EXTRA_ROOT, lambda folder, files:
                       os.path.isdir(os.path.join(folder, 'train_ann'))):
    items += [('myfood', *item) for item in myfood_items(root)]
for root in find_roots(EXTRA_ROOT, lambda folder, files: os.path.exists(
        os.path.join(folder, 'annotations', 'Train.json'))):
    items += [('fis', *item) for item in foodinsseg_items(root)
              for _ in range(FIS_REPEAT if item[1] == 'train' else 1)]
stage(f'Touching pieces joined: {joined["before"]} boxes into '
      f'{joined["after"]} | FoodInsSeg train photos used {FIS_REPEAT} times')
if os.path.isdir(os.path.join(EXTRA_ROOT, 'autolabel', 'labels')):
    items += autolabel_items(os.path.join(EXTRA_ROOT, 'autolabel'))
if os.path.isdir(os.path.join(PLATES_DIR, 'labels')):
    items += [item for item in plates_items(PLATES_DIR)
              for _ in range(PLATES_REPEAT)]
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
    if trainer.epoch + 1 > trainer.epochs:
        return   # the final evaluation calls this again after the last epoch
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
    stage(('Resuming ' + LAST) if resume else
          f'Fine-tuning from {FINETUNE_FROM}' if FINETUNE_FROM else
          f'Training from {MODEL}')
    try:
        if resume:
            # last.pt keeps the folders of the machine it came from: point it
            # at this one's photos and output.
            model.train(resume=True, data=DATA_YAML, save_dir=RUN_DIR,
                        workers=2 if ON_COLAB else 4)
        else:
            model.train(data=DATA_YAML, epochs=EPOCHS, imgsz=IMGSZ, batch=BATCH,
                        patience=PATIENCE, seed=SEED, project=OUTPUT_DIR,
                        name='train', exist_ok=True, workers=2 if ON_COLAB else 4,
                        plots=not QUICK_TEST, cos_lr=True, close_mosaic=10,
                        **(dict(optimizer='SGD', lr0=FINETUNE_LR,
                                warmup_epochs=1) if FINETUNE_FROM else {}))
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

# A threshold of its own for each class, on what the app shows: whether a
# food is on the plate at all. One that F1 prefers is kept only for a class
# in at least 20 val photos, and below threshold_box only while 3 of 4 of
# its finds stay right: misses are cheaper to fix in the app than foods
# that are not there. On the cơm phần photos this lowered rice, greens and
# cucumber, and left the meats, where a lower one doubles the wrong finds.
MIN_CLASS_PHOTOS = 20
MIN_PRECISION_BELOW = 0.75
val_images = sorted(os.path.join(YOLO_DIR, 'images', 'val', n)
                    for n in os.listdir(os.path.join(YOLO_DIR, 'images', 'val')))
truth, top = {}, {}
for path in val_images:
    label = os.path.join(YOLO_DIR, 'labels', 'val',
                         os.path.splitext(os.path.basename(path))[0] + '.txt')
    with open(label) as f:
        truth[path] = {int(line.split()[0]) for line in f if line.strip()}
try:
    import torch
    torch.cuda.empty_cache()
except Exception:
    pass
# 16 photos per call: given the whole list, Ultralytics makes it one batch,
# and the 2,940 val photos asked a T4 for 23 GB.
for start in range(0, len(val_images), 16):
    chunk = val_images[start:start + 16]
    for path, result in zip(chunk, model.predict(
            chunk, imgsz=IMGSZ, conf=0.05, iou=0.5, verbose=False)):
        best = {}
        for c, score in zip(result.boxes.cls.tolist(),
                            result.boxes.conf.tolist()):
            best[int(c)] = max(best.get(int(c), 0.0), score)
        top[path] = best


def presence(c, threshold):
    """Photos where class c is found and there, missed, found but not there."""
    hit = miss = wrong = 0
    for path, there in truth.items():
        found = top.get(path, {}).get(c, 0.0) >= threshold
        hit += found and c in there
        miss += not found and c in there
        wrong += found and c not in there
    return hit, miss, wrong


threshold_by_class = {}
for c, code in enumerate(CLASSES):
    if sum(c in there for there in truth.values()) < MIN_CLASS_PHOTOS:
        continue
    def score(threshold):
        hit, miss, wrong = presence(c, threshold)
        return 2 * hit / (2 * hit + miss + wrong) if hit else 0.0
    best = threshold_box
    for threshold in np.arange(0.10, 0.81, 0.02):
        hit, _, wrong = presence(c, threshold)
        right_enough = (threshold >= threshold_box or
                        hit / max(1, hit + wrong) >= MIN_PRECISION_BELOW)
        if right_enough and score(threshold) > score(best) + 0.005:
            best = float(threshold)
    if abs(best - threshold_box) >= 0.04:
        threshold_by_class[code] = round(best, 2)
stage('Per-class box thresholds on val: '
      + (', '.join(f'{k} {v:.2f}' for k, v in threshold_by_class.items())
         or f'none, all {threshold_box:.2f}'))
test = model.val(data=DATA_YAML, split='test', imgsz=IMGSZ, batch=BATCH,
                 plots=False, project=OUTPUT_DIR, name='test', exist_ok=True)
names = model.names
per_class = {}
for i, c in enumerate(test.box.ap_class_index):
    per_class[names[int(c)]] = {'map50': float(test.box.ap50[i]),
                                'map50_95': float(test.box.ap[i])}
results = {'map50': float(test.box.map50), 'map50_95': float(test.box.map),
           'precision': float(test.box.mp), 'recall': float(test.box.mr),
           'threshold_box': threshold_box,
           'threshold_box_by_class': threshold_by_class, 'per_class': per_class,
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
    *(f'threshold_box_{code}: {value:.2f}'
      for code, value in threshold_by_class.items()),
    'threshold_iou: 0.5',
    '',
    f'- Trained: {date.today().isoformat()}, '
    + (f'fine-tuned from {FINETUNE_FROM}' if FINETUNE_FROM else MODEL)
    + f' with Ultralytics '
    f'{ultralytics.__version__}, {IMGSZ} px'
    + ('' if finished else ' (training not finished: best epoch so far)')
    + (', QUICK TEST' if QUICK_TEST else ''),
    f"- Photos: {dict(photos_per_split)} (VietFood67 boxes, MyFood masks, "
    f'FoodInsSeg boxes, its train photos used {FIS_REPEAT} times; touching '
    f'pieces of one food joined, {joined["before"]} boxes into '
    f'{joined["after"]}'
    + (', Grounding DINO and Open Images boxes in train'
       if any(item[0] in ('auto', 'oi') for item in items) else '')
    + (f', MyFoodRepo and Nutrition5k plates in train, used {PLATES_REPEAT} '
       'times' if any(item[0] in ('fr22', 'n5k') for item in items) else '')
    + ')',
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
