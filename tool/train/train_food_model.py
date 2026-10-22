# %% [markdown]
# # MacroRunner – train the food recognition model
#
# Trains the two-output model described in `docs/MODEL_CONTRACT.md`
# (contract 1.5): a softmax over 91 dishes plus "khac" (food the app does not
# know) and an independent probability per component (25). By default it
# trains EfficientNetB3 at 300×300 with the `full` recipe, continuing from the
# 1.4 model (`EXPERIMENT = 'continue'`, see below). The result is the four
# files the app reads from `assets/models/`, plus an int8 copy.
#
# **Continuing from the 1.4 model** (`EXPERIMENT = 'continue'`): the 65 old
# dishes keep their weights and only the 26 new ones start from zero, so 8
# epochs are enough instead of 30. The notebook looks for the 1.4 model's
# `checkpoint.keras`:
# - on Colab in Drive, `macrorunner_train/efficientnetb3_finetune/` (where the
#   1.4 run saved it; from another Google account, copy that file there);
# - on Kaggle in the inputs: add the 1.4 notebook's output, or a dataset
#   holding that file.
# Set `WARM_START` to its path to choose another file.
#
# **The user's own photos** (Settings → "Lưu ảnh để train" in the app, then
# export): on Kaggle upload the zip as a dataset and add it; on Colab put the
# zip in Drive, folder `macrorunner_train/my_photos/`.
#
# **On Kaggle**
# 1. *Add data*: VinaFood21, 30VNFoods (vietnamese-foods), 20FoodVN,
#    VietFood67 (vietfood68), Food-101 (kmader/food41), the 1.4 model and the
#    user's own photos. MyFood downloads by itself from Zenodo.
# 2. *Settings*: Accelerator **GPU T4 x2**, Internet **on**.
# 3. Run once with `QUICK_TEST = True` to check everything. For B3 on Kaggle
#    this still takes 30–60 minutes: attaching the data, reading VietFood67's
#    labels, compiling for two GPUs and two TFLite conversions do not shrink.
#    If the draft session hangs on "Adding data", skip it: Save Version →
#    Save & Run All with `QUICK_TEST = True` runs the same check on its own
#    machine.
# 4. Set `QUICK_TEST = False`, then **Save Version → Save & Run All**. It keeps
#    running with the browser closed; take the files from the *Output* tab.
# 5. Kaggle stops a run at 12 hours. At 11 hours (`TIME_LIMIT_HOURS`) training
#    stops by itself after an epoch and the notebook still evaluates and
#    exports the best epoch so far; the log and `MODEL_CARD.md` say so. To
#    train on: *Add Input → Your Work → Notebooks*, add this notebook's
#    finished version, then **Save & Run All** again with the same settings.
#    Fine-tuning continues from its `last.keras`.
#
# **On Google Colab** (output shows live, photos sit on a fast local disk)
# 1. *Runtime → Change runtime type → T4 GPU*.
# 2. Kaggle key: kaggle.com → *Settings → API Tokens → Generate New Token*.
#    In Colab, the key icon (*Secrets*) on the left: add `KAGGLE_API_TOKEN`
#    with the `KGAT_...` value and turn on notebook access. (A legacy
#    `kaggle.json` works too: `KAGGLE_USERNAME` and `KAGGLE_KEY`.)
# 3. *Runtime → Run all*, then allow Google Drive (and the secret) in the
#    windows that open within the first seconds; only then leave it alone.
#    The datasets download once per session (VietFood67 is 26 GB, Food-101
#    5 GB). Results go to Google Drive, folder `macrorunner_train`.
# 4. After the quick test, set `QUICK_TEST = False` and run all again in the
#    same session, so nothing downloads twice. Keep the tab open.
# 5. Free Colab gives a session about 5 hours, less than B3 needs (7–8 hours
#    of training). At 4¾ hours (`TIME_LIMIT_HOURS`) training stops by itself
#    after an epoch and the notebook evaluates and exports the best epoch so
#    far. Then, or if the session was cut off anyway, run all again with the
#    same settings: each epoch saves `last.keras` to Drive, and fine-tuning
#    continues after the last finished epoch instead of starting over.
#
# The public datasets are merged into one training set. Class folders are
# renamed to the app's codes; classes the app does not have become "khac".
# VietFood67 has bounding boxes, which also give component labels: a plate
# with boxes for rice, braised pork and vegetables but no dish box is a
# *cơm phần*. Its boxes of rice, tofu, spring rolls and cooked greens are
# also cut out as photos of those foods eaten on their own, and so are
# MyFood's masks (rice, chicken breast, eggs, steak on a lunch plate).

# %%
import os
import time

NOTEBOOK_STARTED = time.time()


def stage(text):
    """One timestamped log line, so a long run shows where it is."""
    minutes = (time.time() - NOTEBOOK_STARTED) / 60
    print(f'[{minutes:6.1f} min] {text}', flush=True)


QUICK_TEST = True          # True: a few hundred images, 1 epoch per phase.
# 'scratch' | 'linear' | 'finetune' (report §3) | 'continue': fine-tune on
# from the 1.4 model, its 65 dishes kept, the new ones added (see the top).
EXPERIMENT = 'continue'
BACKBONE = 'efficientnetb3'  # 'efficientnetb3' (ships); any 'efficientnetb0'
                             # to 'efficientnetb7'; 'efficientnetv2b0';
                             # 'mobilenetv3'
# 'full': the whole backbone fine-tuned with a warm-up and cosine learning
# rate, label smoothing and more photos per dish (the model the app ships).
# 'light': the top 40% at a fixed rate (the backbone comparison of v1.3).
RECIPE = 'full'

INPUT_ROOT = os.environ.get('INPUT_ROOT', '/kaggle/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/kaggle/working')
SEED = 42
FULL = RECIPE == 'full'
# Each backbone's own input size; the app reads it from the .tflite file.
# EfficientNet B0–B7 use the sizes they were designed and pretrained for.
EFFICIENTNET_SIZES = {0: 224, 1: 240, 2: 260, 3: 300, 4: 380, 5: 456, 6: 528,
                      7: 600}
IMG = (EFFICIENTNET_SIZES[int(BACKBONE[-1])]
       if BACKBONE[:-1] == 'efficientnetb' else 224)
BATCH = 16 if QUICK_TEST else 64       # total, split across the GPUs
CONTINUE = EXPERIMENT == 'continue'
# Continuing, one head epoch is enough for the new dishes' columns to catch up.
EPOCHS_HEAD = 1 if QUICK_TEST or CONTINUE else (3 if FULL else 5)  # frozen
EPOCHS_FINE = (1 if QUICK_TEST else 8 if CONTINUE else 30 if FULL else 15)
# The 1.4 model to continue from; empty: looked for (see the top).
WARM_START = os.environ.get('WARM_START', '')
PREVIOUS_DISHES = 65   # contract 1.4: DISHES[:65], then "khac"
# Caps the largest classes. 1,500 held 25 dishes back in v1.3.
MAX_PER_DISH = 12 if QUICK_TEST else (4000 if FULL else 1500)
# Dishes with fewer training photos are repeated up to this many, so the
# large classes do not drown them (random crops make the repeats differ).
MIN_TRAIN_PER_DISH = 0 if QUICK_TEST or not FULL else 300
# float16 maths on the T4's tensor cores: about twice as fast. Weights and
# the exported model stay float32.
MIXED_PRECISION = os.environ.get('MIXED_PRECISION', 'gpu')
# Photos of food the app does not know become the extra class "khac", so the
# model can say "not in the app" instead of forcing a close match.
USE_OTHER = True
# Food-101 alone brings 66 classes the app does not have.
MAX_OTHER = 24 if QUICK_TEST else 4000
UNFREEZE_FRACTION = 0.4                 # share of backbone layers fine-tuned
# 30VNFoods and VietFood67 have one "Phở" class for both beef and chicken.
# 'skip' leaves those photos out; 'pho_bo' counts them as beef phở.
MIXED_PHO = 'skip'

# %% [markdown]
# ## On Google Colab: download the datasets
# Skipped on Kaggle, which mounts them itself. Add the team's own photos
# dataset to the list once it is on Kaggle.

# %%
import glob
import shutil
import sys
import time

ON_COLAB = 'google.colab' in sys.modules
ON_KAGGLE = bool(os.environ.get('KAGGLE_KERNEL_RUN_TYPE'))
# Kaggle stops a run at 12 hours and may keep none of its files; free Colab
# disconnects after about 5. Training stops on its own before that, keeping
# time to evaluate and export the best epoch, and the next run continues it
# (see "Resume" below). 0: no limit.
TIME_LIMIT_HOURS = float(os.environ.get(
    'TIME_LIMIT_HOURS', 11 if ON_KAGGLE else 4.75 if ON_COLAB else 0))
KAGGLE_DATASETS = [
    'lnguynanhnht/20foodvn',
    'quandang/vietnamese-foods',
    'sonbui25/vinafood21',
    'thomasnguyen6868/vietfood68',   # 26 GB
    'kmader/food41',                 # Food-101, 5 GB
]
# Not on Kaggle: downloaded on Kaggle (Internet on) and on Colab alike.
URL_DATASETS = {
    # MyFood (Freitas et al. 2020), CC BY 4.0: 9 foods with masks.
    'myfood': 'https://zenodo.org/records/4041488/files/MyFood%20Dataset.zip?download=1',
}
DOWNLOAD_URL_DATASETS = os.environ.get('DOWNLOAD_URL_DATASETS', '1') == '1'
SAVE_TO_DRIVE = True   # False: results stay in /content/output (lost on exit)
COLAB_ROOT = os.environ.get('COLAB_ROOT', '/content')

if ON_COLAB:
    # Drive first: Colab asks for access here, so the question comes at the
    # start, not after 40 minutes of downloads with nobody at the screen.
    if SAVE_TO_DRIVE:
        from google.colab import drive
        print('Allow Google Drive access in the window that opens now.',
              flush=True)
        drive.mount(os.path.join(COLAB_ROOT, 'drive'))
        # One folder per run, so the backbones do not overwrite each other's
        # results.
        OUTPUT_DIR = os.path.join(
            COLAB_ROOT, 'drive', 'MyDrive', 'macrorunner_train',
            f"{BACKBONE}_{EXPERIMENT}{'_quick' if QUICK_TEST else ''}")
        try:
            with open(os.path.join(OUTPUT_DIR, 'progress.json')) as f:
                print('Earlier progress on Drive:', f.read(), '- training '
                      'continues from there after the downloads.', flush=True)
        except OSError:
            print('No earlier progress on Drive: training starts fresh. If '
                  'you copied progress to a Drive, stop now: the Drive just '
                  'allowed belongs to another Google account.', flush=True)
    else:
        OUTPUT_DIR = os.path.join(COLAB_ROOT, 'output')

    from google.colab import userdata
    for key in ('KAGGLE_USERNAME', 'KAGGLE_KEY', 'KAGGLE_API_TOKEN'):
        try:
            value = userdata.get(key)
        except Exception:   # not added, or notebook access is off
            value = None
        if value:
            os.environ[key] = value
    if not os.environ.get('KAGGLE_API_TOKEN') and not os.environ.get('KAGGLE_KEY'):
        print('No Kaggle key in Colab secrets: add KAGGLE_API_TOKEN '
              '(or KAGGLE_USERNAME + KAGGLE_KEY) and turn on notebook access.')
    # The new KGAT_ tokens need a recent kagglehub; Colab's may be older.
    import subprocess
    subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', '-U',
                    'kagglehub'], check=True)
    import kagglehub

    INPUT_ROOT = os.path.join(COLAB_ROOT, 'datasets')
    os.makedirs(INPUT_ROOT, exist_ok=True)
    for ref in KAGGLE_DATASETS:
        started = time.time()
        print(f'Downloading {ref} ...', flush=True)
        try:
            path = kagglehub.dataset_download(ref)
        except Exception as error:
            raise RuntimeError(
                f'Could not download {ref}: {error}. Check the Colab secret '
                'KAGGLE_API_TOKEN (or KAGGLE_USERNAME + KAGGLE_KEY), with '
                'notebook access on.') from error
        # Named like on Kaggle, so the photos keep the same source names.
        link = os.path.join(INPUT_ROOT, ref.split('/')[1])
        if not os.path.lexists(link):
            os.symlink(path, link)
        print(f'  done in {time.time() - started:.0f} s: {path}', flush=True)
    print(f'Disk free: {shutil.disk_usage(COLAB_ROOT).free / 1e9:.0f} GB')

# Datasets this notebook downloads or unzips itself; Kaggle's input folder
# is read-only.
EXTRA_ROOT = os.environ.get('EXTRA_ROOT', INPUT_ROOT if ON_COLAB else
                            '/tmp/extra_datasets' if ON_KAGGLE else
                            os.path.join(OUTPUT_DIR, 'extra'))
os.makedirs(EXTRA_ROOT, exist_ok=True)


def unzip(zip_path, folder):
    import zipfile
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(folder + '.part')
    os.replace(folder + '.part', folder)


for name, url in URL_DATASETS.items():
    folder = os.path.join(EXTRA_ROOT, name)
    if os.path.isdir(folder) or not DOWNLOAD_URL_DATASETS:
        continue
    started = time.time()
    print(f'Downloading {name} ...', flush=True)
    try:
        import urllib.request
        urllib.request.urlretrieve(url, folder + '.zip')
        unzip(folder + '.zip', folder)
        os.remove(folder + '.zip')
        print(f'  done in {time.time() - started:.0f} s', flush=True)
    except Exception as error:   # no Internet: train without it
        print(f'  FAILED ({error}): its dishes get fewer photos. On Kaggle, '
              'turn Internet on in Settings.', flush=True)

if ON_COLAB and SAVE_TO_DRIVE:
    # The user's own photos, exported from the app as zip files.
    for zip_path in sorted(glob.glob(os.path.join(
            COLAB_ROOT, 'drive', 'MyDrive', 'macrorunner_train', 'my_photos',
            '*.zip'))):
        folder = os.path.join(EXTRA_ROOT, 'my_photos_' + os.path.splitext(
            os.path.basename(zip_path))[0])
        if not os.path.isdir(folder):
            unzip(zip_path, folder)
            print('Own photos:', zip_path, flush=True)

os.makedirs(OUTPUT_DIR, exist_ok=True)
print('Photos from', INPUT_ROOT, 'and', EXTRA_ROOT, '| results to', OUTPUT_DIR)

# %% [markdown]
# ## Contract
# Codes in output order. They must match `dishes.txt` and `components.txt`,
# which this notebook writes at the end.

# %%
CONTRACT_VERSION = '1.5'
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
    # 1.4: dishes the public datasets have, which were "khac" before.
    'banh_trang_nuong', 'banh_gio', 'banh_bot_loc', 'banh_duc', 'nem_chua',
    'banh_pia', 'bun_ca', 'khoai_tay_chien', 'salad', 'hamburger',
    'nui_xao_bo', 'sup_cua', 'nom_hoa_chuoi',
    # 1.5: everyday food, on its own or from abroad.
    'com_trang', 'uc_ga', 'trung_luoc', 'trung_op', 'trung_chien',
    'bo_bit_tet', 'mi_y', 'tao', 'dau_hu_chien', 'rau_xao', 'cha_gio',
    'ga_ran', 'ca_hoi', 'muc_chien', 'sui_cao', 'pizza', 'sushi', 'sashimi',
    'ramen', 'hot_dog', 'sandwich', 'pancake', 'banh_waffle', 'banh_donut',
    'banh_kem', 'kem',
]
OTHER = 'khac'   # last dish output; not an app dish (contract §6)
COMPONENTS = [
    'com', 'bun', 'banh_pho', 'mi', 'banh_mi_o', 'xoi_nep', 'suon_nuong',
    'thit_nuong', 'thit_kho', 'bi', 'cha_trung', 'trung_op_la', 'trung_kho',
    'ga', 'ga_chien', 'bo', 'ca', 'tom', 'dau_hu', 'cha_lua', 'rau_song',
    'rau_nau', 'do_chua', 'dua_leo_ca_chua', 'mo_hanh',
]
assert len(DISHES) == 91 and len(COMPONENTS) == 25
OUTPUTS = DISHES + ([OTHER] if USE_OTHER else [])
# Components each dish's recipe lists (assets/data/vn_food/dishes.csv; checked
# by tool/check_vn_food.py). A component outside a dish's recipe is taken as
# absent from its photos, so every photo teaches the component output, not
# only the VietFood67 ones with boxes.
DISH_PARTS = {
    'com_tam': ('com', 'suon_nuong', 'bi', 'cha_trung', 'trung_op_la', 'do_chua', 'dua_leo_ca_chua', 'mo_hanh'),
    'com_phan': ('com', 'thit_kho', 'trung_kho', 'ca', 'ga', 'ga_chien', 'dau_hu', 'rau_nau'),
    'com_ga': ('com', 'ga_chien', 'dua_leo_ca_chua', 'rau_song'),
    'com_chien': ('com', 'trung_op_la', 'ga', 'tom', 'dua_leo_ca_chua'),
    'pho_bo': ('banh_pho', 'bo', 'rau_song'),
    'pho_ga': ('banh_pho', 'ga', 'rau_song'),
    'bun_bo_hue': ('bun', 'bo', 'cha_lua', 'rau_song'),
    'bun_cha': ('bun', 'thit_nuong', 'rau_song', 'do_chua'),
    'bun_rieu': ('bun', 'dau_hu', 'cha_lua', 'rau_song'),
    'bun_thit_nuong': ('bun', 'thit_nuong', 'rau_song', 'do_chua', 'mo_hanh'),
    'hu_tieu': ('mi', 'tom', 'rau_song'),
    'mi_quang': ('mi', 'tom', 'trung_kho', 'rau_song'),
    'banh_canh': ('mi', 'tom', 'cha_lua'),
    'bo_kho': ('bo', 'banh_mi_o'),
    'chao': ('ga',),
    'banh_mi': ('banh_mi_o', 'cha_lua', 'thit_nuong', 'trung_op_la', 'do_chua', 'dua_leo_ca_chua', 'rau_song'),
    'banh_cuon': ('cha_lua', 'rau_song'),
    'banh_xeo': ('tom', 'rau_song'),
    'goi_cuon': ('bun', 'tom', 'rau_song'),
    'xoi': ('xoi_nep', 'cha_lua', 'trung_kho', 'mo_hanh'),
    'bo_la_lot': ('bun', 'rau_song'),
    'ha_cao': (),
    'banh_uot': ('cha_lua', 'rau_song'),
    'banh_hoi': ('thit_nuong', 'rau_song', 'mo_hanh'),
    'thit_kho_trung': ('thit_kho', 'trung_kho', 'com'),
    'banh_can': (),
    'ca_ri': ('ga', 'banh_mi_o'),
    'bap_nuong': (),
    'banh_trang_tron': (),
    'hoanh_thanh_nuoc': (),
    'pha_lau': ('banh_mi_o',),
    'tau_hu': (),
    'bot_chien': (),
    'ga_nuong': ('ga', 'rau_song', 'dua_leo_ca_chua'),
    'banh_u': (),
    'banh_tet': (),
    'goi_ga': ('ga', 'rau_song'),
    'canh_khoai_mo': (),
    'canh_kho_qua': (),
    'banh_mi_chao': ('banh_mi_o', 'trung_op_la', 'cha_lua'),
    'banh_chung': (),
    'banh_khot': ('rau_song',),
    'banh_beo': ('mo_hanh',),
    'cao_lau': ('mi', 'thit_nuong', 'rau_song'),
    'bun_dau': ('bun', 'dau_hu', 'cha_lua', 'rau_song'),
    'bun_mam': ('bun', 'tom', 'ca', 'rau_song'),
    'chao_long': (),
    'ca_kho': ('com', 'rau_nau'),
    'canh_chua': (),
    'trung_vit_lon': (),
    'che': (),
    'nuoc_mia': (),
    'banh_trang_nuong': (),
    'banh_gio': (),
    'banh_bot_loc': (),
    'banh_duc': (),
    'nem_chua': (),
    'banh_pia': (),
    'bun_ca': ('bun', 'ca', 'rau_song'),
    'khoai_tay_chien': (),
    'salad': (),
    'hamburger': (),
    'nui_xao_bo': ('bo',),
    'sup_cua': (),
    'nom_hoa_chuoi': (),
    'com_trang': ('com',),
    'uc_ga': (),
    'trung_luoc': ('trung_kho',),
    'trung_op': ('trung_op_la',),
    'trung_chien': (),
    'bo_bit_tet': (),
    'mi_y': (),
    'tao': (),
    'dau_hu_chien': ('dau_hu',),
    'rau_xao': ('rau_nau',),
    'cha_gio': (),
    'ga_ran': ('ga_chien',),
    'ca_hoi': (),
    'muc_chien': (),
    'sui_cao': (),
    'pizza': (),
    'sushi': (),
    'sashimi': (),
    'ramen': (),
    'hot_dog': (),
    'sandwich': (),
    'pancake': (),
    'banh_waffle': (),
    'banh_donut': (),
    'banh_kem': (),
    'kem': (),
}
assert set(DISH_PARTS) == set(DISHES)
# 1.5 dishes costed by their base row alone (ức gà, sushi…): chicken, rice or
# fish is on the photo but not in the recipe, so these photos teach the
# component output nothing rather than "no chicken" (contract §2).
NO_COMPONENT_LABELS = {d for d in DISHES[PREVIOUS_DISHES:] if not DISH_PARTS[d]}
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
    # Food-101 (pizza, sushi, sashimi, ramen, hot_dog and hamburger are
    # already app codes; its other classes become "khac").
    'steak': 'bo_bit_tet',
    'filet_mignon': 'bo_bit_tet',
    'prime_rib': 'bo_bit_tet',
    'omelette': 'trung_chien',
    'spaghetti_bolognese': 'mi_y',
    'spaghetti_carbonara': 'mi_y',
    'spring_rolls': 'cha_gio',
    'chicken_wings': 'ga_ran',
    'grilled_salmon': 'ca_hoi',
    'fried_calamari': 'muc_chien',
    'dumplings': 'sui_cao',
    'gyoza': 'sui_cao',
    'club_sandwich': 'sandwich',
    'grilled_cheese_sandwich': 'sandwich',
    'pulled_pork_sandwich': 'sandwich',
    'lobster_roll_sandwich': 'sandwich',
    'pancakes': 'pancake',
    'waffles': 'banh_waffle',
    'donuts': 'banh_donut',
    'chocolate_cake': 'banh_kem',
    'cheesecake': 'banh_kem',
    'red_velvet_cake': 'banh_kem',
    'strawberry_shortcake': 'banh_kem',
    'carrot_cake': 'banh_kem',
    'cup_cakes': 'banh_kem',
    'ice_cream': 'kem',
    'fried_rice': 'com_chien',
    'french_fries': 'khoai_tay_chien',
    'caesar_salad': 'salad',
    'greek_salad': 'salad',
    'beet_salad': 'salad',
    'caprese_salad': 'salad',
    # Like an app dish but not one: left out rather than taught as "khac".
    'frozen_yogurt': None,
    'seaweed_salad': None,
    'chicken_curry': 'ca_ri',
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
    'Bun cha ca': 'bun_ca', 'Nom hoa chuoi': 'nom_hoa_chuoi',
    'Nui xao bo': 'nui_xao_bo', 'Sup cua': 'sup_cua',
    'Hamburger': 'hamburger', 'Khoai tay chien': 'khoai_tay_chien',
    'Salad': 'salad',
}
# Sides: the dish only when nothing else is (fries next to a burger, a salad
# next to rice are not the meal).
VF_SIDES = {'Khoai tay chien', 'Salad'}
# Whole dishes VietFood67 has but the app does not: photos of them are "khac".
VF_OTHER = {'Lau'}
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
# Boxes also cut out as a photo of that food on its own (1.5). Greens count
# only on a cơm phần plate: next to phở or bún they are raw herbs.
VF_CROPS = {'Com': 'com_trang', 'Dau hu': 'dau_hu_chien', 'Cha gio': 'cha_gio',
            'Rau': 'rau_xao'}
VF_CROP_ONLY_ON = {'Rau': {'com_phan'}}
CROP_MIN_SIDE = 0.2   # smaller boxes, as a share of the photo, are too blurry
CROP_MARGIN = 0.08    # a little of the plate around the box


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


# MyFood: mask value → its class (1 is food it left unnamed), and the dish
# each class is in the app. Brazilian beans are not an app dish.
MYFOOD_CLASSES = {2: 'apple', 3: 'bean', 4: 'boiled_egg', 5: 'chicken_breast',
                  6: 'rice', 7: 'salad', 8: 'spaghetti', 9: 'fried_egg',
                  10: 'steak'}
MYFOOD_DISH = {'apple': 'tao', 'bean': 'khac', 'boiled_egg': 'trung_luoc',
               'chicken_breast': 'uc_ga', 'rice': 'com_trang', 'salad': 'salad',
               'spaghetti': 'mi_y', 'fried_egg': 'trung_op',
               'steak': 'bo_bit_tet'}
# The app's photo labels (contract §5): one food eaten on its own is the
# dish that means the same, if there is one.
OWN_SINGLE = {'com': 'com_trang', 'trung_kho': 'trung_luoc',
              'trung_op_la': 'trung_op', 'dau_hu': 'dau_hu_chien',
              'rau_nau': 'rau_xao', 'ga_chien': 'ga_ran'}


def sure_parts(dish):
    """The components a photo of [dish] surely shows: those of a one-part
    recipe (plain rice is rice)."""
    parts = DISH_PARTS.get(dish, ())
    return set(parts) if len(parts) == 1 else set()

# %% [markdown]
# ## Collect every photo

# %%
import csv
import hashlib
import random

import numpy as np
from PIL import Image
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
# Folder names that hold photos but say nothing about the dish.
GENERIC_FOLDERS = {'images', 'image', 'imgs', 'img', 'photos', 'pictures',
                   'data', 'dataset', 'train', 'training', 'test', 'testing',
                   'val', 'valid', 'validation'}


def top_of(path):
    """INPUT_ROOT or EXTRA_ROOT, whichever holds [path] most closely."""
    roots = [r for r in (INPUT_ROOT, EXTRA_ROOT)
             if path == r or path.startswith(r.rstrip(os.sep) + os.sep)]
    return max(roots, key=len) if roots else INPUT_ROOT


def class_folder(folder):
    """The nearest folder name above the photos that is not generic, e.g.
    'goi_cuon' for 20FoodVN/goi_cuon/images/1.jpg."""
    for name in reversed(os.path.relpath(folder, top_of(folder)).split(os.sep)):
        if normalize(name) not in GENERIC_FOLDERS:
            return name
    return os.path.basename(folder)


random.seed(SEED)
samples = []   # dicts: path, box, dish, present (set), observed (set), source
skipped = Counter()


def add(path, dish, source, present=(), observed=(), box=None):
    """[box]: (left, top, right, bottom) as shares of the photo, to train on
    that part only."""
    # Photos are opened later, only for the ones kept; the small JPEG copies
    # made then also cover WebP, which TensorFlow cannot decode.
    samples.append({'path': path, 'box': box, 'dish': dish, 'source': source,
                    'present': set(present), 'observed': set(observed)})


def padded(left, top, right, bottom):
    m = CROP_MARGIN
    return (max(0.0, left - m * (right - left)), max(0.0, top - m * (bottom - top)),
            min(1.0, right + m * (right - left)), min(1.0, bottom + m * (bottom - top)))


def is_detection_root(folder):
    return (os.path.isdir(os.path.join(folder, 'images')) and
            os.path.isdir(os.path.join(folder, 'labels')))


def load_vietfood67(root, source):
    label_paths = sorted(
        os.path.join(folder, name)
        for folder, _, names in os.walk(os.path.join(root, 'labels'),
                                        followlinks=True)
        for name in names if name.endswith('.txt'))
    if QUICK_TEST:
        # A tenth of the labels still gives every dish its 12 photos, and
        # the quick test then does not wait on 33,000 reads.
        label_paths = label_paths[::10]
    stage(f'{source}: {len(label_paths)} label files listed')
    # One listing of the images instead of a lookup per label: the datasets
    # sit on a network disk, where every file check is slow.
    images_root = os.path.join(root, 'images')
    image_files = {}
    for folder, _, names in os.walk(images_root, followlinks=True):
        for name in sorted(names):
            stem, ext = os.path.splitext(name)
            if ext.lower() in IMAGE_EXT:
                rel = os.path.relpath(os.path.join(folder, stem), images_root)
                image_files.setdefault(rel, os.path.join(folder, name))
    stage(f'{source}: {len(image_files)} images listed')

    def read_boxes(label_path):
        """[(name, (left, top, right, bottom))] of one YOLO label file."""
        boxes = []
        with open(label_path) as f:
            for line in f:
                parts = line.split()
                if (len(parts) >= 5 and parts[0].isdigit() and
                        int(parts[0]) < len(VF_NAMES)):
                    try:
                        cx, cy, w, h = (float(p) for p in parts[1:5])
                    except ValueError:
                        continue
                    boxes.append((VF_NAMES[int(parts[0])],
                                  (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)))
        return boxes

    all_boxes = []
    with ThreadPoolExecutor(32) as pool:
        for start in range(0, len(label_paths), 5000):
            all_boxes += pool.map(read_boxes, label_paths[start:start + 5000])
            stage(f'{source}: {len(all_boxes)} of {len(label_paths)} labels read')
    for label_path, boxes in zip(label_paths, all_boxes):
        names = {name for name, _ in boxes}
        rel = os.path.relpath(label_path, os.path.join(root, 'labels'))
        image = image_files.get(os.path.splitext(rel)[0])
        if image is None:
            skipped['vf67: no image'] += 1
            continue
        dishes = {VF_DISH[n] for n in names - VF_SIDES if n in VF_DISH} - {None}
        sides = {VF_DISH[n] for n in names & VF_SIDES}
        if len(dishes) > 1:
            dish = None
            skipped['vf67: several dishes'] += 1
        elif dishes:
            dish = dishes.pop()
        elif 'Com' in names and names & PROTEIN_BOXES:
            dish = 'com_phan'   # rice with mains and no dish box
        elif len(sides) == 1:
            dish = sides.pop()  # fries or a salad on their own
        elif USE_OTHER and names & VF_OTHER:
            dish = OTHER        # a dish the app does not have
        else:
            dish = None
            skipped['vf67: no app dish'] += 1
        # The largest box of each food that can be eaten on its own.
        largest = {}
        for name, (left, top, right, bottom) in boxes:
            if (name in VF_CROPS and dish in VF_CROP_ONLY_ON.get(name, {dish}) and
                    min(right - left, bottom - top) >= CROP_MIN_SIDE):
                area = (right - left) * (bottom - top)
                if area > largest.get(name, (0, None))[0]:
                    largest[name] = (area, (left, top, right, bottom))
        for name, (_, box) in largest.items():
            crop_dish = VF_CROPS[name]
            parts = sure_parts(crop_dish)
            add(image, crop_dish, source, parts, parts, box=padded(*box))
        if dish is None:
            continue
        present, observed = vf_resolve(dish, names)
        add(image, dish, source, present, observed)


def is_myfood_root(folder):
    return all(os.path.isdir(os.path.join(folder, name))
               for name in ('train', 'train_ann'))


def load_myfood(root, source):
    """MyFood: each photo's mask cut into one photo per food on it."""
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
            for value, food in MYFOOD_CLASSES.items():
                ys, xs = np.nonzero(values == value)
                # Specks of a food the photo is not about.
                if len(ys) < 0.03 * values.size:
                    continue
                dish = MYFOOD_DISH[food]
                if dish == OTHER and not USE_OTHER:
                    continue
                box = (xs.min() / width, ys.min() / height,
                       (xs.max() + 1) / width, (ys.max() + 1) / height)
                add(os.path.join(folder, name), dish, source, sure_parts(dish),
                    sure_parts(dish), box=padded(*box))


def is_own_photos(folder, files):
    """A photo zip exported from the app (contract §5)."""
    if 'index.csv' not in files:
        return False
    with open(os.path.join(folder, 'index.csv'), encoding='utf-8') as f:
        return 'model_guess' in f.readline()


def load_own_photos(folder, source):
    with open(os.path.join(folder, 'index.csv'), encoding='utf-8') as f:
        for row in csv.DictReader(f):
            label = row['label'].strip()
            if label.startswith('single_'):
                dish = OWN_SINGLE.get(label[len('single_'):])
            elif label.startswith('new_'):
                dish = OTHER if USE_OTHER else None
            else:
                dish = label if label in DISH_INDEX else None
            if dish is None:
                skipped[f'own photos: {label}'] += 1
                continue
            add(os.path.join(folder, row['file']), dish, source,
                sure_parts(dish), sure_parts(dish))


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
    parts = os.path.relpath(path, top_of(path)).split(os.sep)
    if parts[0] == 'datasets' and len(parts) > 2:
        return parts[2]
    return parts[0]


# Each folder is handled by the first rule that matches: the team's
# labels.csv, the app's photo zip (index.csv), a detection dataset (images/
# + labels/), MyFood (train/ + train_ann/), or class folders.
handled = []   # roots already loaded, whose subfolders are skipped below
announced = set()
collect_started = time.time()


def announce(source, folder):
    """One log line per dataset, so a long run shows where it is."""
    if source not in announced:
        announced.add(source)
        print(f'[{time.time() - collect_started:4.0f} s] reading {source} '
              f'({folder})', flush=True)


# Kaggle may mount datasets as symlinks, which os.walk skips by default.
visited = set()   # real paths: a symlinked dataset is read once, never in a loop
walk = [step for top in dict.fromkeys([INPUT_ROOT, EXTRA_ROOT])
        for step in [os.walk(top, followlinks=True)]]
for folder, dirs, files in (entry for step in walk for entry in step):
    dirs.sort()
    real = os.path.realpath(folder)
    if real in visited:
        dirs[:] = []
        continue
    visited.add(real)
    if any(folder == root or folder.startswith(root + os.sep) for root in handled):
        dirs[:] = []
        continue
    if 'labels.csv' in files:
        announce(source_name(folder), folder)
        load_team_labels(os.path.join(folder, 'labels.csv'), source_name(folder))
        handled.append(folder)
        dirs[:] = []
    elif is_own_photos(folder, files):
        announce(source_name(folder), folder)
        load_own_photos(folder, source_name(folder))
        handled.append(folder)
        dirs[:] = []
    elif is_myfood_root(folder):
        announce(source_name(folder), folder)
        load_myfood(folder, source_name(folder))
        handled.append(folder)
        dirs[:] = []
    elif is_detection_root(folder):
        announce(source_name(folder), folder)
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
        announce(source, folder)
        if dish is None:
            skipped[f'{source}: {name}'] += len(images)
            continue
        for name in sorted(images):
            add(os.path.join(folder, name), dish, source)

print(f'[{time.time() - collect_started:4.0f} s] found {len(samples)} photos',
      flush=True)


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
from PIL import Image, ImageOps


def crop(im, box):
    """[im] cut to [box] (shares of the photo), or [im] when box is None."""
    if box is None:
        return im
    left, top, right, bottom = box
    return im.crop((round(left * im.width), round(top * im.height),
                    max(round(left * im.width) + 1, round(right * im.width)),
                    max(round(top * im.height) + 1, round(bottom * im.height))))


def average_hash(path, box=None):
    try:
        with Image.open(path) as im:
            if box is None:
                im.draft('L', (64, 64))   # JPEG: decode at a fraction of the size
            small = crop(im, box).convert('L').resize((8, 8), Image.BILINEAR)
            pixels = np.asarray(small, dtype=np.float32).flatten().tolist()
    except Exception:
        return None
    mean = sum(pixels) / len(pixels)
    return sum(1 << i for i, p in enumerate(pixels) if p > mean)


# Training reads each photo every epoch. Full-size photos made Colab's two
# CPU cores the bottleneck (about 40 photos/s, 15 minutes an epoch), so every
# kept photo is decoded once here and saved with its short side SHRUNK_SIDE.
# 384 keeps even the smallest random crop (60%, 230 px) above the 224×224
# input, so every crop is still scaled down, never up: no detail is lost.
# Large enough that the smallest random crop (60% of the short side) still
# covers the input: 384 for 224-pixel models, 512 for B3's 300.
SHRUNK_SIDE = max(384, -(-IMG * 10 // 6 // 32) * 32)
SHRUNK_DIR = os.environ.get('SHRUNK_DIR', '/tmp/shrunk')
os.makedirs(SHRUNK_DIR, exist_ok=True)


def shrink(path, box=None):
    """A small upright JPEG copy of [path], or of its [box], reused if already
    made; None when the photo cannot be read."""
    key = path if box is None else f'{path}|' + ','.join(f'{v:.4f}' for v in box)
    digest = hashlib.md5(key.encode('utf-8')).hexdigest()
    target = os.path.join(SHRUNK_DIR, f'{digest}.jpg')
    if os.path.exists(target):
        return target
    try:
        with Image.open(path) as im:
            # JPEG: decode straight at a fraction of the size, much faster.
            if box is None:
                im.draft('RGB', (SHRUNK_SIDE, SHRUNK_SIDE))
            # Upright like the app's photos, which follow EXIF orientation.
            # Boxes were drawn on the upright photo too.
            im = crop(ImageOps.exif_transpose(im), box).convert('RGB')
            scale = SHRUNK_SIDE / min(im.size)
            if scale < 1:
                im = im.resize((max(1, round(im.width * scale)),
                                max(1, round(im.height * scale))),
                               Image.BILINEAR)
            im.save(target, quality=90)
    except Exception:
        return None
    return target


def prepare(s):
    """(small copy, hash) for one photo; (None, None) when it cannot be read."""
    h = average_hash(s['path'], s['box'])
    file = shrink(s['path'], s['box']) if h is not None else None
    return (file, h) if file is not None else (None, None)


# Sorted and shuffled with a fixed seed, so every run (and every teammate)
# gets the same split. Each dish is read in that order only until it is full,
# so the cap also saves opening photos that would be thrown away. The
# datasets sit on a network disk, hence the threads.
samples.sort(key=lambda s: (s['path'], s['box'] or ()))
pending = defaultdict(list)
for s in samples:
    pending[s['dish']].append(s)
by_dish = defaultdict(list)
seen = {}
opened = 0
started = time.time()
with ThreadPoolExecutor(32) as pool:
    for dish, items in sorted(pending.items()):
        random.Random(f'{SEED}-{dish}').shuffle(items)
        cap = MAX_OTHER if dish == OTHER else MAX_PER_DISH
        kept = by_dish[dish]
        start = 0
        while start < len(items) and len(kept) < cap:
            # A little more than the dish still needs, for duplicates.
            size = min(256, max(32, 2 * (cap - len(kept))))
            chunk = items[start:start + size]
            start += size
            opened += len(chunk)
            for s, (file, h) in zip(chunk, pool.map(prepare, chunk)):
                if len(kept) >= cap:
                    break
                if file is None:
                    skipped['unreadable'] += 1
                elif h in seen:
                    skipped['duplicate'] += 1
                else:
                    seen[h] = s['path']
                    kept.append({**s, 'file': file})
print(f'Opened {opened} of {len(samples)} photos in '
      f'{time.time() - started:.0f} s', flush=True)

train, val, test = [], [], []
for dish, items in sorted(by_dish.items()):
    n_test = max(1, round(len(items) * 0.15)) if len(items) >= 3 else 0
    n_val = max(1, round(len(items) * 0.15)) if len(items) >= 3 else 0
    test += items[:n_test]
    val += items[n_test:n_test + n_val]
    train += items[n_test + n_val:]
print(f'train {len(train)}, val {len(val)}, test {len(test)}; '
      f'duplicates dropped {skipped["duplicate"]}')
unique_train = list(train)
with open(os.path.join(OUTPUT_DIR, 'splits.csv'), 'w', newline='',
          encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['file', 'box', 'split', 'dish', 'source'])
    for split, items in (('train', train), ('val', val), ('test', test)):
        for s in items:
            box = ' '.join(f'{v:.4f}' for v in s['box']) if s['box'] else ''
            writer.writerow([s['path'], box, split, s['dish'], s['source']])

if MIN_TRAIN_PER_DISH:
    # After splits.csv, which lists each photo once.
    grouped = defaultdict(list)
    for s in train:
        grouped[s['dish']].append(s)
    train = []
    for dish, items in sorted(grouped.items()):
        repeat = max(1, -(-MIN_TRAIN_PER_DISH // len(items)))
        train += (items * repeat)[:max(len(items), MIN_TRAIN_PER_DISH)]
    print(f'Training on {len(train)} photos after repeating small dishes')

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

# "GPU T4 x2" gives two GPUs, but Keras uses only the first unless training
# runs under MirroredStrategy, which splits every batch between them. BATCH
# stays the total, so a run on one GPU learns the same way.
if len(tf.config.list_physical_devices('GPU')) > 1:
    # NCCL all-reduce, the default, can hang at the first step on Kaggle's
    # T4 x2; copying gradients through the host is slower but safe.
    strategy = tf.distribute.MirroredStrategy(
        cross_device_ops=tf.distribute.HierarchicalCopyAllReduce())
else:
    strategy = tf.distribute.MirroredStrategy()
# Grappler's add-op rewrite gives the loss a temporary variable that is
# still alive when the next epoch starts, and training stops with
# ALREADY_EXISTS at epoch 2. Without that rewrite a step is no slower here.
tf.config.optimizer.set_experimental_options({'arithmetic_optimization': False})
if MIXED_PRECISION == 'always' or (
        MIXED_PRECISION == 'gpu' and tf.config.list_physical_devices('GPU')):
    keras.mixed_precision.set_global_policy('mixed_float16')
print('Precision:', keras.mixed_precision.global_policy().name)
print('GPUs:', len(tf.config.list_physical_devices('GPU')),
      '| training on', strategy.num_replicas_in_sync, 'device(s)')


def targets(s):
    """(one-hot dish, component labels + mask) for one photo."""
    labels = np.zeros(N_COMP, np.float32)
    mask = np.zeros(N_COMP, np.float32)
    absent = set()
    if s['dish'] in DISH_PARTS and s['dish'] not in NO_COMPONENT_LABELS:
        # Off the dish's recipe: known absent (unless a box shows it).
        absent = set(COMPONENTS) - set(DISH_PARTS[s['dish']]) - set(s['present'])
    for c in s['present']:
        labels[COMP_INDEX[c]] = 1
    for c in set(s['observed']) | absent:
        mask[COMP_INDEX[c]] = 1
    dish = np.zeros(N_DISH, np.float32)
    dish[DISH_INDEX[s['dish']]] = 1
    return dish, np.concatenate([labels, mask])


def make_dataset(items, training):
    paths = [s['file'] for s in items]   # the small copies made above
    dish, comp = zip(*(targets(s) for s in items)) if items else ((), ())
    ds = tf.data.Dataset.from_tensor_slices(
        (paths, np.array(dish, np.float32).reshape(-1, N_DISH),
         np.array(comp, np.float32).reshape(-1, 2 * N_COMP)))
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
            if FULL:
                image = tf.image.random_saturation(image, 0.85, 1.15)
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


stage('photos ready, building the input pipeline')
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
    elif BACKBONE[:-1] == 'efficientnetb' and BACKBONE[-1] in '01234567':
        # Always normalizes raw 0–255 RGB itself, so it has no switch for it.
        del common['include_preprocessing']
        base = getattr(keras.applications,
                       f'EfficientNetB{BACKBONE[-1]}')(**common)
    elif BACKBONE == 'efficientnetv2b0':
        base = keras.applications.EfficientNetV2B0(**common)
    else:
        raise ValueError(BACKBONE)
    inputs = keras.Input((IMG, IMG, 3), name='image')  # raw RGB 0–255
    # Pretrained batch-norm statistics stay fixed while fine-tuning.
    x = base(inputs, training=EXPERIMENT == 'scratch')
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.2)(x)
    # float32 outputs, also under mixed precision, for stable losses.
    dish = keras.layers.Dense(N_DISH, activation='softmax', name='dish',
                              dtype='float32')(x)
    comp = keras.layers.Dense(N_COMP, activation='sigmoid', name='components',
                              dtype='float32')(x)
    return keras.Model(inputs, {'dish': dish, 'components': comp}), base


def masked_bce(y_true, y_pred):
    """Binary cross-entropy over the components a photo's labels cover."""
    labels, mask = y_true[:, :N_COMP], y_true[:, N_COMP:]
    bce = keras.backend.binary_crossentropy(labels, y_pred)
    return tf.reduce_sum(bce * mask, axis=-1) / tf.maximum(
        tf.reduce_sum(mask, axis=-1), 1.0)


with strategy.scope():
    model, base = build_model()


def find_warm_start():
    """Paths that may hold the 1.4 model, most likely first."""
    if WARM_START:
        return [WARM_START]
    found = []
    if ON_COLAB and SAVE_TO_DRIVE:
        found.append(os.path.join(COLAB_ROOT, 'drive', 'MyDrive',
                                  'macrorunner_train',
                                  f'{BACKBONE}_finetune', 'checkpoint.keras'))
    # Notebook outputs and small datasets sit at most three folders deep.
    for depth in range(4):
        found += sorted(glob.glob(os.path.join(
            INPUT_ROOT, *['*'] * depth, '*.keras')))
    return [p for p in dict.fromkeys(found) if os.path.exists(p) and
            os.path.dirname(os.path.abspath(p)) != os.path.abspath(OUTPUT_DIR)
            and os.path.basename(p) != 'last.keras']


def warm_start():
    """Copies the 1.4 model into [model]: the backbone and the component
    output as they are, the dish output column by column. The 65 old dishes
    keep their place and "khac" moves to the end; the new dishes start from
    fresh weights. Returns the file used, or None."""
    for path in find_warm_start():
        try:
            old = keras.models.load_model(
                path, custom_objects={'masked_bce': masked_bce}, compile=False)
        except Exception as error:
            print('Not a model:', path, error)
            continue
        old_dish = old.get_layer('dish')
        if (old_dish.units != PREVIOUS_DISHES + 1 or
                old.input_shape[1:3] != (IMG, IMG)):
            print(f'Skipped {path}: {old_dish.units} dish outputs at '
                  f'{old.input_shape[1:3]}, not {PREVIOUS_DISHES + 1} at {IMG}')
            continue
        old_base = next(l for l in old.layers if isinstance(l, keras.Model))
        base.set_weights(old_base.get_weights())
        model.get_layer('components').set_weights(
            old.get_layer('components').get_weights())
        kernel, bias = (w.copy() for w in model.get_layer('dish').get_weights())
        old_kernel, old_bias = old_dish.get_weights()
        kernel[:, :PREVIOUS_DISHES] = old_kernel[:, :PREVIOUS_DISHES]
        bias[:PREVIOUS_DISHES] = old_bias[:PREVIOUS_DISHES]
        if USE_OTHER:
            kernel[:, -1], bias[-1] = old_kernel[:, -1], old_bias[-1]
        # New dishes start as likely as an average old one.
        bias[PREVIOUS_DISHES:len(DISHES)] = old_bias[:PREVIOUS_DISHES].mean()
        model.get_layer('dish').set_weights([kernel, bias])
        del old
        stage(f'continuing from {path}')
        return path
    if not QUICK_TEST:
        raise RuntimeError(
            'EXPERIMENT is "continue" but no 1.4 model (checkpoint.keras with '
            f'{PREVIOUS_DISHES + 1} dish outputs) was found. Add it (see the '
            'top of the notebook), set WARM_START, or set EXPERIMENT to '
            '"finetune" to train from ImageNet.')
    print('No 1.4 model found: the quick test starts from ImageNet.')
    return None


def compile_model(learning_rate, weight_decay=0.0):
    with strategy.scope():
        optimizer = (keras.optimizers.AdamW(learning_rate,
                                            weight_decay=weight_decay)
                     if weight_decay else keras.optimizers.Adam(learning_rate))
        model.compile(
            optimizer=optimizer,
            loss={'dish': keras.losses.CategoricalCrossentropy(
                      label_smoothing=0.1 if FULL else 0.0),
                  'components': masked_bce},
            metrics={'dish': ['accuracy']},
        )


import json
import math

CHECKPOINT = os.path.join(OUTPUT_DIR, 'checkpoint.keras')   # best so far
LAST = os.path.join(OUTPUT_DIR, 'last.keras')               # where to resume
PROGRESS = os.path.join(OUTPUT_DIR, 'progress.json')


def read_progress():
    try:
        with open(PROGRESS) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_progress(phase, epoch, logs):
    best = max(read_progress().get('best', -1.0),
               float(logs.get('val_dish_accuracy', -1.0)))
    if nan_loss['hit']:
        return   # this epoch is thrown away
    minutes = earlier_minutes + (time.time() - started) / 60
    with open(PROGRESS + '.tmp', 'w') as f:
        json.dump({'phase': phase, 'epochs_done': epoch + 1, 'best': best,
                   'backbone': BACKBONE, 'recipe': RECIPE,
                   'experiment': EXPERIMENT, 'contract': CONTRACT_VERSION,
                   'warm_start': warm_started,
                   'quick_test': QUICK_TEST,
                   'train_minutes': round(minutes, 1)}, f)
    os.replace(PROGRESS + '.tmp', PROGRESS)


out_of_time = []   # set once training stopped for the time limit
nan_loss = {'hit': False}   # the loss became NaN in the running epoch
epoch_started = [time.time()]


def check_time(phase, epoch):
    """Stops training when one more epoch would leave too little time to
    evaluate and export: 20 minutes before TIME_LIMIT_HOURS. The short head
    phase always runs to the end."""
    if not TIME_LIMIT_HOURS or phase == 'head' or model.stop_training:
        return
    epoch_minutes = (time.time() - epoch_started[0]) / 60
    used = (time.time() - NOTEBOOK_STARTED) / 60
    if used + epoch_minutes > TIME_LIMIT_HOURS * 60 - 20:
        model.stop_training = True
        out_of_time.append(epoch + 1)
        stage(f'time limit near after epoch {epoch + 1}: stopping here and '
              'keeping the best epoch; the next run continues')


first_step = []   # phases whose first training step was logged


class SaveModel(keras.callbacks.Callback):
    """Saves the model, optimizer included, after each epoch, or only after
    a better one with [best_only]. It writes a temporary file and then
    renames it, so a session cut off while saving keeps the previous file
    whole."""

    def __init__(self, path, best_only=False, best=None):
        super().__init__()
        self.path, self.best_only, self.best = path, best_only, best

    def on_epoch_end(self, epoch, logs=None):
        if nan_loss['hit']:
            return   # never save weights that turned into NaN
        value = (logs or {}).get('val_dish_accuracy')
        if self.best_only:
            if value is None or (self.best is not None and value <= self.best):
                return
            self.best = value
        temporary = self.path[:-len('.keras')] + '.tmp.keras'
        self.model.save(temporary)
        os.replace(temporary, self.path)


class StopOnNaN(keras.callbacks.Callback):
    """Stops at the first batch whose loss is NaN or infinite. On Kaggle's
    two T4s the B3 loss once turned into NaN at fine-tuning epoch 6, every
    weight with it, and the run idled six more epochs until EarlyStopping.
    Stopping here keeps that epoch from being saved; the training cell then
    goes back to the last saved epoch and trains on."""

    def __init__(self, phase):
        super().__init__()
        self.phase, self.epoch = phase, 0

    def on_epoch_begin(self, epoch, logs=None):
        self.epoch = epoch

    def on_train_batch_end(self, batch, logs=None):
        loss = (logs or {}).get('loss')
        if loss is not None and not math.isfinite(float(loss)):
            nan_loss['hit'] = True
            self.model.stop_training = True
            stage(f'{self.phase} epoch {self.epoch + 1}, batch {batch + 1}: '
                  'the loss is NaN, stopping this epoch')


def callbacks(phase, best=None):
    """[best]: the best validation accuracy before a resume, so the best
    checkpoint is only replaced by a better epoch."""
    return [
        StopOnNaN(phase),
        SaveModel(CHECKPOINT, best_only=True, best=best),
        # Every epoch, with the optimizer, so a cut-off session continues.
        SaveModel(LAST),
        keras.callbacks.CSVLogger(
            os.path.join(OUTPUT_DIR, f'training_log_{phase}.csv'),
            append=best is not None),
        keras.callbacks.EarlyStopping(monitor='val_dish_accuracy', mode='max',
                                      patience=6 if FULL else 3,
                                      restore_best_weights=True),
        # The first step shows the GPUs work together; then one line an epoch.
        keras.callbacks.LambdaCallback(
            on_train_batch_end=lambda batch, logs: (
                stage(f'{phase}: first training step done'),
                first_step.append(phase)) if batch == 0 and
            phase not in first_step else None,
            on_epoch_begin=lambda epoch, logs: epoch_started.__setitem__(
                0, time.time()),
            on_epoch_end=lambda epoch, logs: (
                save_progress(phase, epoch, logs),
                stage(f"{phase} epoch {epoch + 1}: val dish accuracy "
                      f"{logs.get('val_dish_accuracy', 0):.3f}"),
                check_time(phase, epoch))),
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
earlier_minutes = 0.0
warm_started = None   # the 1.4 model this run continues from
# A session cut off during fine-tuning (Colab's free GPU time, a closed tab)
# continues from its last epoch when the notebook runs again with the same
# settings: last.keras holds the model and the optimizer, learning-rate
# schedule included.
#
# On Kaggle each version starts with an empty /kaggle/working. To continue,
# add the previous version's output as data (Add Input → Your Work →
# Notebooks); its files are copied here first.
RESUME_FILES = [PROGRESS, LAST, CHECKPOINT,
                os.path.join(OUTPUT_DIR, 'training_log_head.csv'),
                os.path.join(OUTPUT_DIR, 'training_log_fine.csv')]
if not os.path.exists(PROGRESS):
    # Notebook outputs sit at most three folders deep in /kaggle/input;
    # deeper folders are the photo datasets, too many files to search.
    found = sorted(
        glob.glob(os.path.join(INPUT_ROOT, 'progress.json')) +
        glob.glob(os.path.join(INPUT_ROOT, '*', 'progress.json')) +
        glob.glob(os.path.join(INPUT_ROOT, '*', '*', 'progress.json')) +
        glob.glob(os.path.join(INPUT_ROOT, '*', '*', '*', 'progress.json')))
    for path in found:
        folder = os.path.dirname(path)
        try:
            with open(path) as f:
                # Before 1.5 progress had no experiment: those were finetune.
                same = json.load(f).get('experiment', 'finetune') == EXPERIMENT
        except (OSError, ValueError):
            same = False
        if same and os.path.exists(os.path.join(folder, 'last.keras')):
            print('Previous run found in', folder)
            for target in RESUME_FILES:
                source = os.path.join(folder, os.path.basename(target))
                if os.path.exists(source):
                    shutil.copy(source, target)
            break
progress = read_progress()
progress.setdefault('experiment', 'finetune')   # saved before 1.5
progress.setdefault('contract', '1.4')
SAME_RUN = (('backbone', BACKBONE), ('recipe', RECIPE),
            ('quick_test', QUICK_TEST), ('experiment', EXPERIMENT),
            ('contract', CONTRACT_VERSION))
resume = (EXPERIMENT in ('finetune', 'continue') and
          progress.get('phase') == 'fine' and os.path.exists(LAST) and
          all(progress.get(k) == v for k, v in SAME_RUN) and
          progress.get('epochs_done', 0) < EPOCHS_FINE)
if not resume and progress.get('phase') == 'fine':
    # Fine-tuning progress that cannot be continued: never delete it and
    # start over silently, hours of training may sit in last.keras.
    differ = [f"{k}: saved {progress.get(k)!r}, now {v!r}"
              for k, v in SAME_RUN if progress.get(k) != v]
    if progress.get('epochs_done', 0) >= EPOCHS_FINE:
        differ.append(f"all {EPOCHS_FINE} fine-tuning epochs are done")
    if not os.path.exists(LAST):
        differ.append('last.keras is missing')
    raise RuntimeError(
        f'{OUTPUT_DIR} holds fine-tuning progress that this run cannot '
        f"continue ({'; '.join(differ) or EXPERIMENT}). To start over, "
        'move or rename that folder first.')
if resume:
    stage(f"resuming fine-tuning after epoch {progress['epochs_done']} "
          f"(best val {progress['best']:.3f})")
    earlier_minutes = progress.get('train_minutes', 0.0)
    warm_started = progress.get('warm_start')
    with strategy.scope():
        model = keras.models.load_model(
            LAST, custom_objects={'masked_bce': masked_bce})
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE,
              initial_epoch=progress['epochs_done'],
              callbacks=callbacks('fine', best=progress['best']))
elif EXPERIMENT == 'scratch':
    base.trainable = True
    compile_model(1e-3)
    model.fit(train_ds, validation_data=val_ds,
              epochs=EPOCHS_HEAD + EPOCHS_FINE, callbacks=callbacks('scratch'))
else:
    for stale in (PROGRESS, LAST):   # a fresh run
        if os.path.exists(stale):
            os.remove(stale)
    if CONTINUE:
        warm_started = warm_start()
    base.trainable = False
    compile_model(1e-3)
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD,
              callbacks=callbacks('head'))
    if EXPERIMENT in ('finetune', 'continue'):
        base.trainable = True
        cut = 0 if FULL else int(len(base.layers) * (1 - UNFREEZE_FRACTION))
        for layer in base.layers[:cut]:
            layer.trainable = False
        for layer in base.layers:
            if isinstance(layer, keras.layers.BatchNormalization):
                layer.trainable = False
        if FULL:
            # A short warm-up, then cosine decay to zero over the epochs.
            steps = max(1, -(-len(train) // BATCH)) * EPOCHS_FINE
            warmup = max(1, steps // 20)
            # Continuing: a third of the rate, not to undo what 1.4 learned.
            compile_model(keras.optimizers.schedules.CosineDecay(
                0.0, steps - warmup, warmup_target=1e-4 if CONTINUE else 3e-4,
                warmup_steps=warmup), weight_decay=1e-5)
        else:
            compile_model(1e-4)
        model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE,
                  callbacks=callbacks('fine'))
# A NaN loss: back to the last saved fine-tuning epoch, a few times. The
# photos come in another order, so the same batch rarely blows up again.
for attempt in range(3):
    progress = read_progress()
    if not nan_loss['hit'] or out_of_time:
        break
    if progress.get('phase') != 'fine' or not os.path.exists(LAST):
        print('The loss became NaN before any fine-tuning epoch was saved; '
              'the best epoch so far is kept.')
        break
    stage(f"going back to the end of fine epoch {progress['epochs_done']} "
          f'(try {attempt + 1} of 3)')
    nan_loss['hit'] = False
    with strategy.scope():
        model = keras.models.load_model(
            LAST, custom_objects={'masked_bce': masked_bce})
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE,
              initial_epoch=progress['epochs_done'],
              callbacks=callbacks('fine', best=progress['best']))

train_minutes = earlier_minutes + (time.time() - started) / 60
print(f'Training took {train_minutes:.1f} min')
progress = read_progress()
FINISHED = not out_of_time and not nan_loss['hit']
if nan_loss['hit']:
    print('The loss kept turning into NaN; training stopped at fine epoch '
          f"{progress.get('epochs_done')} and the best epoch is kept.")
if out_of_time:
    print(f"Stopped for the time limit after fine-tuning epoch "
          f"{progress.get('epochs_done')} of {EPOCHS_FINE}. These files are "
          "usable. To train on, " + (
              "run all again in a new session." if ON_COLAB else
              "run a new version with this version's output added as data."))
# The best epoch over the whole run, also across resumed sessions.
if os.path.exists(CHECKPOINT):
    best_model = keras.models.load_model(
        CHECKPOINT, custom_objects={'masked_bce': masked_bce}, compile=False)
    model.set_weights(best_model.get_weights())
    del best_model

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
        dish_true.append(y['dish'].numpy().argmax(axis=-1))
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


def component_precision(comp_true, comp_prob, threshold):
    labels, mask = comp_true[:, :N_COMP], comp_true[:, N_COMP:]
    guess = (comp_prob >= threshold) & (mask > 0)
    truth = (labels > 0) & (mask > 0)
    return (guess & truth).sum() / max(1, guess.sum())


stage('training done, evaluating')
val_pred, test_pred = predict(val_ds), predict(test_ds)
threshold = 0.6
if val_pred is not None and val_pred[1][:, N_COMP:].sum() > 0:
    grid = [round(t, 2) for t in np.arange(0.3, 0.91, 0.05)]
    if FULL:
        # A wrong tick adds food the user did not eat, so ticking needs 85%
        # precision; among those thresholds the lowest keeps the most ticks.
        precise = [t for t in grid if component_precision(
            val_pred[1], val_pred[3], t) >= 0.85]
        threshold = min(precise) if precise else max(grid)
    else:
        threshold = max(grid, key=lambda t: component_f1(
            val_pred[1], val_pred[3], t))
thresholds = {
    'threshold_checked': float(threshold),
    'threshold_ask': float(round(max(0.15, threshold - 0.3), 2)),
    'threshold_confident_dish': 0.5,
}

results = {'experiment': EXPERIMENT, 'backbone': BACKBONE, 'recipe': RECIPE,
           'img': IMG, 'contract': CONTRACT_VERSION, 'warm_start': warm_started,
           'quick_test': QUICK_TEST, 'train_minutes': round(train_minutes, 1),
           'finished': FINISHED,
           'epochs_fine_done': progress.get('epochs_done'),
           'photos': {'train': len(train), 'val': len(val), 'test': len(test)},
           'params': int(model.count_params()),
           **thresholds}
# Dishes whose components the model learned: enough validation photos with
# component labels, and a good F1 on them. For every other dish the app
# ignores the component outputs and ticks the recipe (contract §6): a phở
# photo once got eggs and pork skin "seen" at over 60%, because no phở photo
# had component labels.
COMPONENT_MIN_PHOTOS, COMPONENT_MIN_F1 = 20, 0.7
component_dishes = []
if val_pred is not None:
    for i, code in enumerate(DISHES):
        rows = (val_pred[0] == i) & (val_pred[1][:, N_COMP:].sum(axis=1) > 0)
        if (rows.sum() >= COMPONENT_MIN_PHOTOS and
                component_f1(val_pred[1][rows], val_pred[3][rows],
                             threshold) >= COMPONENT_MIN_F1):
            component_dishes.append(code)
results['component_dishes'] = component_dishes
print('Components trusted for:', component_dishes or 'no dish')
if val_pred is not None:
    # The backbones are compared on validation; test is reported only.
    results['val_dish_top1'] = float(
        (val_pred[2].argmax(axis=1) == val_pred[0]).mean())
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

# Copy the trained model outside the GPU strategy, so the converter sees
# plain variables instead of one copy per GPU. Built from the model's config,
# the copy keeps every layer (EfficientNetB0 adds its input scaling only when
# it loads ImageNet weights, so rebuilding it would not).
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


def finalize_normalization(m):
    """set_weights copies a Normalization layer's mean and variance but does
    not apply them (EfficientNetB0 has one); finalize_state() does."""
    for layer in m.layers:
        if isinstance(layer, keras.layers.Normalization):
            layer.finalize_state()
        elif hasattr(layer, 'layers'):
            finalize_normalization(layer)


finalize_normalization(export_model)
sample_check = next(iter(test_ds if test else val_ds))[0][:1]
assert np.abs(export_model(sample_check, training=False)['dish'].numpy() -
              model(sample_check, training=False)['dish'].numpy()).max() < (
                  0.02 if model.dtype_policy.name == 'mixed_float16' else 1e-4),     'The export copy differs from the trained model'
stage('converting to float16 TFLite')
converter = tf.lite.TFLiteConverter.from_keras_model(export_model)
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
# Speed on this machine's CPU: only for comparing backbones, a phone differs.
for _ in range(5):
    interpreter.invoke()
timed = time.time()
for _ in range(30):
    interpreter.invoke()
results['tflite_mb'] = round(size_mb, 2)
results['cpu_ms'] = round((time.time() - timed) / 30 * 1000, 1)

# An int8-weight copy (dynamic range), half the size. It ships only if a
# phone runs it as fast and it scores as well, so it is measured here on the
# same test photos as the float16 file.
stage('converting to int8 TFLite')
converter = tf.lite.TFLiteConverter.from_keras_model(export_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
int8 = converter.convert()
stage('measuring both TFLite files on test photos')
with open(os.path.join(OUTPUT_DIR, 'food_v1_int8.tflite'), 'wb') as f:
    f.write(int8)


def lite_top1(content, limit=1000):
    lite = tf.lite.Interpreter(model_content=content)
    lite.allocate_tensors()
    (inp,) = lite.get_input_details()
    out = next(o for o in lite.get_output_details() if o['shape'][-1] == N_DISH)
    hits = total = 0
    for images, y in test_ds:
        for image, truth in zip(images.numpy(), y['dish'].numpy().argmax(-1)):
            lite.set_tensor(inp['index'], image[None])
            lite.invoke()
            hits += int(lite.get_tensor(out['index'])[0].argmax() == truth)
            total += 1
            if total >= limit:
                return hits / total
    return hits / max(1, total)


results['int8'] = {'tflite_mb': round(len(int8) / 1e6, 2),
                   'test_top1_sample': round(lite_top1(int8), 4),
                   'float16_test_top1_sample': round(lite_top1(tflite), 4)}
print('int8 copy:', results['int8'])
with open(os.path.join(OUTPUT_DIR, 'results.json'), 'w') as f:
    json.dump(results, f, indent=2)
print(f"TFLite {size_mb:.1f} MB, {results['cpu_ms']} ms per photo on this CPU")


def metric(name):
    value = results.get(name)
    return 'chưa có nhãn thành phần' if value is None else f'{value:.3f}'

sources = Counter(s['source'] for s in train + val + test)
card = f"""# MODEL_CARD – food_v1

- Ngày train: {date.today().isoformat()}
- Contract: {CONTRACT_VERSION} ({len(DISHES)} món{' + lớp khac' if USE_OTHER else ''}, {N_COMP} thành phần)
- Kiến trúc: {BACKBONE} ({IMG}×{IMG}), thí nghiệm `{EXPERIMENT}`, cách train `{RECIPE}`{' (CHẠY THỬ, KHÔNG DÙNG THẬT)' if QUICK_TEST else ''}{f'''
- Train tiếp từ: model contract 1.4 ({os.path.basename(warm_started)})''' if warm_started else ''}
- Dữ liệu: {len(train)} train / {len(val)} val / {len(test)} test
- Nguồn ảnh: {', '.join(f'{k}: {v}' for k, v in sources.most_common())}
- Kích thước: {size_mb:.1f} MB (float16)
- Thời gian train: {train_minutes:.0f} phút{'' if FINISHED else f" (DỪNG VÌ HẾT GIỜ sau epoch {progress.get('epochs_done')}/{EPOCHS_FINE}, chạy lại để train tiếp)" if out_of_time else f" (DỪNG VÌ LOSS BỊ NaN sau epoch {progress.get('epochs_done')}/{EPOCHS_FINE})"}

## Kết quả trên tập test
- Món, top-1: {metric('dish_top1')}
- Món, top-3: {metric('dish_top3')}
- Thành phần, F1: {metric('component_f1')}

## Ngưỡng (app đọc các dòng này)
threshold_checked: {thresholds['threshold_checked']}
threshold_ask: {thresholds['threshold_ask']}
threshold_confident_dish: {thresholds['threshold_confident_dish']}
component_dishes: {', '.join(component_dishes)}

## Hạn chế
- Tập test chưa có ảnh tự chụp: contract yêu cầu ít nhất 30%.
- Nhãn thành phần chỉ có ở ảnh VietFood67 và ảnh tự gán; các ảnh còn lại
  chỉ dạy phần đoán món.{'''
- Train tiếp từ model 1.4, nhưng ảnh chia lại vì có thêm bộ ảnh: một số ảnh
  test lần này model 1.4 đã thấy khi train, nên điểm test có thể cao hơn
  thực tế.''' if warm_started else ''}
"""
with open(os.path.join(OUTPUT_DIR, 'MODEL_CARD.md'), 'w', encoding='utf-8') as f:
    f.write(card)
print(card)
stage('done')
print('Download from Output:', sorted(os.listdir(OUTPUT_DIR)))
if ON_COLAB and SAVE_TO_DRIVE:
    # Drive uploads in the background; this waits until every file is there.
    drive.flush_and_unmount()
    print('All files are on Google Drive.')
