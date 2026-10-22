"""Builds a tiny fake copy of the training datasets in Kaggle's
/kaggle/input/datasets/<owner>/<slug> layout, enough for the notebook to run
end to end on a CPU in a few minutes: VinaFood21, 30VNFoods, 20FoodVN,
VietFood67, Food-101, MyFood and a photo zip exported from the app.

    python tool/train/test/make_fake_input.py <folder>
"""
import csv
import os
import random
import sys

from PIL import Image, ImageDraw


def photo(path, seed):
    """One photo; its colour comes from the hundreds of [seed], so all photos
    of a folder share one colour and the model has something to learn."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rng = random.Random(seed)
    shade = (seed // 100 * 37) % 230 + 20
    im = Image.new('RGB', (rng.randint(260, 400), rng.randint(220, 380)),
                   (shade, 255 - shade, (shade * 7) % 256))
    for _ in range(30):
        x, y = rng.randint(0, 200), rng.randint(0, 180)
        im.paste(tuple(rng.randint(0, 255) for _ in range(3)),
                 (x, y, x + 12, y + 12))
    im.save(path)


def make(root):
    data = os.path.join(root, 'datasets')
    # Folder → number of photos.
    folders = {
        'sonbui25/vinafood21/VinaFood21/train/bo_kho': 14,
        'sonbui25/vinafood21/VinaFood21/test/banh_tet': 14,
        'quandang/vietnamese-foods/Images/Train/Bánh mì': 14,
        'quandang/vietnamese-foods/Images/Train/Phở': 14,
        # Not an app dish: becomes "khac".
        'quandang/vietnamese-foods/Images/Train/Cao lầu': 14,
        # Food-101: an app code, an alias, and "khac".
        'kmader/food41/images/pizza': 14,
        'kmader/food41/images/steak': 14,
        'kmader/food41/images/apple_pie': 14,
    }
    for index, (folder, count) in enumerate(folders.items()):
        for i in range(count):
            photo(os.path.join(data, folder, f'{i}.jpg'), index * 100 + i)
    # 20FoodVN keeps photos in <dish>/images next to a meta.json.
    for index, dish in enumerate(['che_thai', 'goi_cuon', 'hu_tieu_nam_vang',
                                  'pho_bo']):
        folder = os.path.join(data, 'lnguynanhnht/20foodvn/20FoodVN', dish)
        for i in range(14):
            photo(os.path.join(folder, 'images', f'{i}.jpg'),
                  1000 + index * 100 + i)
        with open(os.path.join(folder, 'meta.json'), 'w') as f:
            f.write('{}')
    # One .webp among the photos: the notebook must read it too.
    folder = os.path.join(data, 'lnguynanhnht/20foodvn/20FoodVN/goi_ngo_sen/images')
    for i in range(12):
        photo(os.path.join(folder, f'x{i}.{"webp" if i == 0 else "jpg"}'), 2000 + i)
    # VietFood67: YOLO boxes; the class ids decide dish and components.
    vf = os.path.join(data, 'thomasnguyen6868/vietfood68/dataset')
    plates = {
        'comtam': [26, 56, 22, 25],   # Com tam, Trung, Cha, Com
        'comphan': [25, 53, 48],      # Com, Thit kho, Rau: a cơm phần
        'twodish': [26, 4],           # two dishes: skipped
        'onlyveg': [48],              # no app dish: skipped
    }
    for index, (kind, ids) in enumerate(plates.items()):
        for i in range(14):
            photo(os.path.join(vf, 'images/train', f'{kind}{i}.jpg'),
                  3000 + index * 100 + i)
            os.makedirs(os.path.join(vf, 'labels/train'), exist_ok=True)
            with open(os.path.join(vf, 'labels/train', f'{kind}{i}.txt'),
                      'w') as f:
                # Side by side, so the crops of each box differ.
                for j, c in enumerate(ids):
                    f.write(f'{c} {0.2 + 0.2 * j:.2f} 0.5 0.3 0.4\n')
    # MyFood: masks whose values are the food (6 rice, 5 chicken breast).
    myfood = os.path.join(data, 'me/myfood/MyFood Dataset')
    for split in ('train', 'val', 'test'):
        os.makedirs(os.path.join(myfood, f'{split}_ann'), exist_ok=True)
        for i in range(5):
            image = os.path.join(myfood, split, f'lunch_{i}.png')
            photo(image, 4000 + i)
            with Image.open(image) as im:
                size = im.size
            mask = Image.new('RGBA', size, (0, 0, 0, 255))
            draw = ImageDraw.Draw(mask)
            draw.rectangle((0, 0, size[0] // 2, size[1] - 1), fill=(6, 6, 6, 255))
            draw.rectangle((size[0] // 2 + 1, 0, size[0] - 1, size[1] // 2),
                           fill=(5, 5, 5, 255))
            mask.save(os.path.join(myfood, f'{split}_ann', f'lunch_{i}.png'))
    # The app's photo export (contract §5).
    own = os.path.join(data, 'me/my-photos')
    rows = []
    for k, label in enumerate(['pho_bo', 'single_com', 'new_yen_mach',
                               'single_bi']):
        for i in range(4):
            file = f'{label}/{i}.jpg'
            photo(os.path.join(own, file), 5000 + k * 100 + i)
            rows.append([file, label, label, 'com_tam', '0.412',
                         '2026-10-22T08:00:00'])
    with open(os.path.join(own, 'index.csv'), 'w', newline='',
              encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['file', 'label', 'name', 'model_guess',
                         'model_confidence', 'saved_at'])
        writer.writerows(rows)


if __name__ == '__main__':
    make(sys.argv[1])
    print('fake input ready in', sys.argv[1])
