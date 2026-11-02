"""Builds plates.zip, extra train photos for train_detector.ipynb: plates with
the foods the detector missed most on the cơm phần photos (chicken, pork,
beef, greens).

- MyFoodRepo (Food Recognition 2022, Kaggle `awsaf49/food-recognition-2022-dataset`,
  CC BY 4.0): phone photos of meals with an outline around each food. The
  boxes come from the outlines: the dataset's own bbox field is wrong (it
  often repeats x as y).
- Nutrition5k (Hugging Face `ai5labsOfficial/nutrition5k`, CC BY 4.0):
  cafeteria plates shot from above, with the weight of every ingredient but
  no boxes. Grounding DINO looks for the ingredients the plate holds, and
  the class of a box is the ingredient's, as in autolabel_detector.ipynb.
  The current detector checks the weak boxes. It also checks MyFoodRepo:
  a photo where it is sure of a meat that no outline covers is left out.

Photos with a food that may look like one of ours without being one of
ours (bread, pasta, sausage, ham, bacon…) are left out, so the detector is
not taught that it is background. So are photos with none of the weak
classes. Everything goes to the train split.

    python tool/train/make_plates_data.py --fr22 DIR --n5k DIR \
        --teacher detector_best.pt --out DIR

--fr22: the folder with public_training_set_release_2.0/annotations.json.
--n5k: the folder with metadata.csv and images/{dish_id}.png.
Either may be left out. Nutrition5k needs torch, transformers 4.56 and
ultralytics 8.4.185; on a GPU it takes about 0.3 s a photo. Writes
plates.zip, PLATES_CARD.md and preview.jpg to --out, and plates_labels.zip:
the same without the photos (under 1 MB), which train_detector.ipynb fills
from the original datasets.
"""
import argparse
import csv
import json
import os
import random
import shutil
import zipfile
from collections import Counter
from datetime import date

from PIL import Image, ImageDraw, ImageOps

CLASSES = [
    'com', 'bun', 'mi', 'banh_mi_o', 'ga', 'thit_kho', 'thit_nuong', 'heo',
    'bo', 'ca', 'tom', 'muc', 'trung', 'dau_hu', 'cha', 'cha_gio', 'rau',
    'dua_leo_ca_chua', 'do_chua', 'khoai_tay_chien', 'canh',
]
CLASS_INDEX = {code: i for i, code in enumerate(CLASSES)}
WEAK = {'ga', 'heo', 'bo', 'rau'}
MEATS = {'ga', 'heo', 'bo'}
LONG_SIDE = 640          # as train_detector.ipynb shrinks its photos
SEED = 0
# Photos whose only weak class is greens: MyFoodRepo has 2,000 green salads,
# which would crowd out the meat.
MAX_GREENS_ONLY = 800


def classes_of(groups):
    return {name: code for code, names in groups.items() for name in names}


# MyFoodRepo category → class.
FR22_CLASS = classes_of({
    'ga': ['chicken', 'chicken-breast', 'chicken-cut-into-stripes-only-meat',
           'chicken-leg', 'chicken-wing'],
    'heo': ['pork', 'pork-chop', 'pork-roast'],
    'bo': ['beef', 'beef-filet', 'beef-sirloin-steak', 'beef-roast',
           'beef-cut-into-stripes-only-meat'],
    'ca': ['salmon', 'fish', 'cod', 'perch-fillets-lake'],
    'tom': ['shrimp-prawn-large', 'shrimp-prawn-small', 'shrimp-boiled'],
    'com': ['rice', 'rice-basmati', 'rice-whole-grain', 'rice-jasmin',
            'rice-wild', 'cantonese-fried-rice'],
    'bun': ['rice-noodles-vermicelli'],
    'trung': ['egg', 'egg-scrambled-prepared', 'omelette-plain'],
    'dau_hu': ['tofu'],
    'cha_gio': ['spring-roll-fried'],
    'rau': ['salad-leaf-salad-green', 'mixed-salad-chopped-without-sauce',
            'broccoli', 'leaf-spinach', 'salad-rocket', 'salad-lambs-ear',
            'red-cabbage', 'white-cabbage', 'chinese-cabbage', 'swiss-chard',
            'spinach-raw', 'spinach-steamed-without-addition-of-salt',
            'savoy-cabbage-steamed-without-addition-of-salt', 'romanesco',
            'mungbean-sprouts'],
    'dua_leo_ca_chua': ['tomato-raw', 'cucumber'],
    'khoai_tay_chien': ['chips-french-fries'],
})
# Foods that look like one of ours (bread as bánh mì, pasta as mì, ham and
# sausage as chả, minced or breaded meat, rice-like grains, soups as canh,
# vegetable mixes as rau): photos with them are left out.
FR22_UNSURE = {
    'pasta', 'pasta-spaghetti', 'pasta-penne', 'pasta-twist', 'pasta-wholemeal',
    'pasta-linguini-parpadelle-tagliatelle', 'pasta-noodles', 'pasta-hornli',
    'pasta-in-butterfly-form-farfalle', 'pasta-in-conch-form',
    'pasta-ravioli-stuffing', 'pasta-tortelloni-stuffing',
    'high-protein-pasta-made-of-lentils-peas', 'spaetzle', 'lasagne-meat-prepared',
    'lasagne-vegetable-prepared', 'dumplings', 'potato-gnocchi',
    'bread', 'bread-white', 'bread-wholemeal', 'bread-whole-wheat', 'bread-grain',
    'bread-sourdough', 'bread-french-white-flour', 'bread-toast', 'bread-nut',
    'bread-half-white', 'bread-black', 'bread-wholemeal-toast', 'bread-pita',
    'bread-fruit', 'bread-rye', 'bread-5-grain', 'bread-spelt', 'bread-olive',
    'bread-ticino', 'braided-white-loaf', 'croissant', 'croissant-wholegrain',
    'croissant-with-chocolate-filling', 'ham-croissant', 'gluten-free-bread',
    'roll-of-half-white-or-white-flour-with-large-void',
    'roll-with-pieces-of-chocolate', 'fajita-bread-only', 'naan-indien-bread',
    'focaccia', 'brioche', 'hamburger-bun', 'bagel-without-filling',
    'lye-pretzel-soft', 'white-bread-with-butter-eggs-and-milk', 'croutons',
    'sandwich-ham-cheese-and-butter', 'croque-monsieur', 'kebab-in-pita-bread',
    'hamburger', 'hamburger-bread-meat-ketchup', 'bread-meat-substitute-lettuce-sauce',
    'veggie-burger', 'sausage', 'salami', 'ham', 'ham-raw', 'ham-cooked',
    'ham-turkey', 'cervelat', 'veal-sausage', 'wienerli-swiss-sausage',
    'frying-sausage', 'cooked-sausage', 'chorizo',
    'smoked-cooked-sausage-of-pork-and-beef-meat-sausag',
    'processed-meat-charcuterie', 'meat-terrine-pate', 'dried-meat', 'bacon',
    'bacon-frying', 'bacon-cooking', 'bacon-raw', 'meat', 'minced-meat',
    'beef-minced-only-meat', 'tartar-meat', 'meatloaf', 'meat-balls', 'lamb',
    'lamb-chop', 'goat-average-raw', 'pork-escalope',
    'cordon-bleu-from-pork-schnitzel-fried', 'chicken-nuggets',
    'chicken-curry-cream-coconut-milk-curry-spices-paste', 'chili-con-carne-prepared',
    'bolognaise-sauce', 'turnover-with-meat-small-meat-pie-empanadas',
    'fish-fingers-breaded', 'fish-crunchies-battered', 'salmon-smoked', 'tuna',
    'tuna-in-oil-drained', 'anchovies', 'sushi', 'risotto-without-cheese-cooked',
    'risotto-with-mushrooms-cooked', 'couscous', 'taboule-prepared-with-couscous',
    'quinoa', 'bulgur', 'ebly', 'buckwheat-grain-peeled', 'mixed-vegetables',
    'vegetables', 'vegetable-mix-peas-and-carrots', 'soup-vegetable',
    'soup-pumpkin', 'soup-of-lentils-dahl-dhal', 'soup-tomato', 'soup-miso',
    'soup-cream-of-vegetables', 'soup-potato', 'bouillon', 'bouillon-vegetable',
    'country-fries', 'cucumber-pickled', 'sauerkraut', 'halloumi', 'feta',
    'curry-vegetarian', 'greek-salad', 'caprese-salad-tomato-mozzarella',
}
# Nutrition5k ingredient → class, counted only from this many grams: less
# is a garnish too small to box.
N5K_MIN_GRAMS = 10
N5K_CLASS = classes_of({
    'ga': ['chicken', 'chicken thighs', 'chicken breast', 'grilled chicken'],
    'heo': ['pork'],
    'bo': ['beef', 'steak', 'brisket'],
    'ca': ['fish', 'salmon', 'tuna', 'cod'],
    'tom': ['shrimp'],
    'com': ['white rice', 'brown rice', 'country rice', 'fried rice', 'wild rice',
            'pilaf'],
    'trung': ['scrambled eggs', 'egg whites', 'eggs', 'omelets'],
    'dau_hu': ['tofu'],
    'rau': ['broccoli', 'mixed greens', 'arugula', 'spinach (raw)',
            'spinach (cooked)', 'lettuce', 'kale', 'bok choy', 'chard',
            'mustard greens', 'cabbage', 'caesar salad', 'garden salad', 'tatsoi',
            'collards'],
    'dua_leo_ca_chua': ['cucumbers', 'cherry tomatoes', 'tomatoes'],
})
N5K_UNSURE = {
    'bacon', 'turkey bacon', 'sausage', 'chicken apple sausage', 'pasta',
    'rice noodles', 'spaghetti', 'lasagna', 'ground turkey', 'turkey', 'lamb',
    'dumplings', 'tempeh', 'hash browns', 'tortilla', 'bagels', 'flatbread',
    'sandwiches', 'bread', 'toast', 'pita bread', 'waffles', 'wheat bread',
    'sourdough bread', 'multigrain bread', 'chicken salad', 'tuna salad',
    'kimchi', 'pepperoni', 'deprecated', 'curries', 'chilaquiles', 'crepes',
    'pasta salad', 'coleslaw', 'cheese pizza', 'pizza', 'pepperoni pizza',
    'greek salad', 'quinoa', 'couscous', 'bulgur', 'millet', 'wheat berry',
}
# What Grounding DINO is asked for, where the ingredient's name is not
# clear on its own.
N5K_PROMPT = {
    'spinach (raw)': 'spinach', 'spinach (cooked)': 'cooked spinach',
    'mixed greens': 'salad greens', 'caesar salad': 'lettuce salad',
    'garden salad': 'lettuce salad', 'egg whites': 'scrambled egg',
    'omelets': 'omelette', 'country rice': 'rice', 'pilaf': 'rice',
}
# A meat or greens of at least this many grams that is not boxed: the photo
# is left out, it would teach that food as background. So is a photo with
# no box at all.
N5K_MEAT_GRAMS = 20
GD_MODEL = 'IDEA-Research/grounding-dino-base'
BOX_MIN, BOX_SURE, TEXT_MIN = 0.3, 0.45, 0.25   # as autolabel_detector
# Diced or sliced chicken breast gets only 0.2-0.37 from Grounding DINO, and
# the detector calls it chả or tofu: a meat box from MEAT_MIN is kept where
# the detector sees any food (IoU from MEAT_AGREE_IOU), the class taken from
# the ingredients.
MEAT_MIN, MEAT_AGREE_IOU = 0.2, 0.3
# The plate's weights say its meat is there: with no meat box by the rules
# above, Grounding DINO's best one from MEAT_MIN is taken if it is between
# these shares of the photo (not a speck, not the whole plate) and its
# centre is this far from the edges (the plate is in the middle; a shoe at
# the edge was once boxed as chicken). Half of those looked right, most of
# the rest covered only part of the meat.
MEAT_ALONE_AREA = (0.03, 0.5)
MEAT_ALONE_EDGE = 0.15
TEACHER_AGREE, TEACHER_SURE = 0.25, 0.6
MAX_AREA = 0.8


def area(b):
    return max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])


def iou(a, b):
    inter = area((max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]),
                  min(a[3], b[3])))
    union = area(a) + area(b) - inter
    return inter / union if union > 0 else 0.0


def shrunk(path, turn=True):
    with Image.open(path) as im:
        if turn:
            im = ImageOps.exif_transpose(im)
        im = im.convert('RGB')
        im.thumbnail((LONG_SIDE, LONG_SIDE))
        return im


class Writer:
    def __init__(self, out):
        self.dir = os.path.join(out, 'plates')
        shutil.rmtree(self.dir, ignore_errors=True)
        for kind in ('images', 'labels'):
            os.makedirs(os.path.join(self.dir, kind, 'train'))
        self.rows, self.boxes = [], Counter()

    def save(self, source, im, boxes, origin):
        """boxes: [(class, left, top, right, bottom)] as shares of the photo."""
        name = f'{source}_{len(self.rows):06d}'
        im.save(os.path.join(self.dir, 'images', 'train', name + '.jpg'),
                quality=90)
        with open(os.path.join(self.dir, 'labels', 'train', name + '.txt'),
                  'w') as f:
            for code, left, top, right, bottom in boxes:
                left, top = max(0.0, left), max(0.0, top)
                right, bottom = min(1.0, right), min(1.0, bottom)
                if right - left > 0.005 and bottom - top > 0.005:
                    f.write(f'{CLASS_INDEX[code]} {(left + right) / 2:.6f} '
                            f'{(top + bottom) / 2:.6f} {right - left:.6f} '
                            f'{bottom - top:.6f}\n')
                    self.boxes[(source, code)] += 1
        self.rows.append((name, source, origin))


def load_detector(path):
    """The current plate detector as a function: photo → [(class, score,
    box)] with boxes as shares of the photo."""
    import torch
    from ultralytics import YOLO

    teacher = YOLO(path)
    assert [teacher.names[i] for i in range(len(teacher.names))] == CLASSES
    device = 0 if torch.cuda.is_available() else 'cpu'

    def detector(im):
        r = teacher.predict(im, imgsz=512, conf=TEACHER_AGREE, iou=0.5,
                            device=device, verbose=False)[0]
        return [(CLASSES[int(c)], float(s), tuple(b)) for c, s, b in zip(
            r.boxes.cls.tolist(), r.boxes.conf.tolist(), r.boxes.xyxyn.tolist())]
    return detector


# Meat classes, with the two the detector has for cooked pork.
ANY_MEAT = MEATS | {'thit_kho', 'thit_nuong'}


def fr22(root, writer, card, detector=None):
    """[detector]: if given, a photo is left out where it is sure of a meat
    that no outline covers, as MyFoodRepo sometimes leaves one unoutlined."""
    rng = random.Random(SEED)
    split = os.path.join(root, 'public_training_set_release_2.0')
    with open(os.path.join(split, 'annotations.json')) as f:
        coco = json.load(f)
    names = {c['id']: c['name'] for c in coco['categories']}
    per_image = {}
    for a in coco['annotations']:
        per_image.setdefault(a['image_id'], []).append(a)
    chosen, skipped = [], Counter()
    for image in coco['images']:
        found = per_image.get(image['id'], [])
        foods = {names[a['category_id']] for a in found}
        codes = {FR22_CLASS[n] for n in foods if n in FR22_CLASS}
        if foods & FR22_UNSURE:
            skipped['a food that may look like ours'] += 1
        elif not codes & WEAK:
            skipped['no chicken, pork, beef or greens'] += 1
        else:
            chosen.append((image, found, codes))
    greens_only = [c for c in chosen if not c[2] & MEATS]
    rng.shuffle(greens_only)
    drop = {id(c) for c in greens_only[MAX_GREENS_ONLY:]}
    skipped['greens only, over MAX_GREENS_ONLY'] = len(drop)
    kept = 0
    for image, found, _ in (c for c in chosen if id(c) not in drop):
        path = os.path.join(split, 'images', image['file_name'])
        try:
            # The outlines are drawn on the photo as stored, not as the
            # camera turned it.
            im = shrunk(path, turn=False)
        except Exception:
            skipped['unreadable photo'] += 1
            continue
        width, height = image['width'], image['height']
        boxes = []
        for a in found:
            code = FR22_CLASS.get(names[a['category_id']])
            points = [p for s in a['segmentation'] for p in s]
            if not code or len(points) < 6:
                continue
            xs, ys = points[0::2], points[1::2]
            boxes.append((code, min(xs) / width, min(ys) / height,
                          max(xs) / width, max(ys) / height))
        if detector and any(
                code in ANY_MEAT and score >= TEACHER_SURE and
                all(iou(box, b[1:]) < 0.3 for b in boxes)
                for code, score, box in detector(im)):
            skipped['a meat with no outline'] += 1
            continue
        writer.save('fr22', im, boxes, image['file_name'])
        kept += 1
    card.append(f'- MyFoodRepo: {kept} photos of {len(coco["images"])}; left '
                f'out: {dict(skipped)}')
    print(card[-1], flush=True)


def n5k(root, writer, card, detector):
    import torch
    from transformers import (AutoModelForZeroShotObjectDetection,
                              AutoProcessor)

    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    processor = AutoProcessor.from_pretrained(GD_MODEL)
    model = AutoModelForZeroShotObjectDetection.from_pretrained(
        GD_MODEL).to(device).eval()

    def grounding(im, prompts):
        """[(class, score, box)]; prompts: {words: class}."""
        inputs = processor(images=im, text='. '.join(prompts) + '.',
                           return_tensors='pt').to(device)
        with torch.no_grad(), torch.autocast(device, enabled=device == 'cuda'):
            out = model(**inputs)
        result = processor.post_process_grounded_object_detection(
            out, inputs.input_ids, threshold=MEAT_MIN, text_threshold=MEAT_MIN,
            target_sizes=[(im.height, im.width)])[0]
        found = []
        for box, score, label in zip(result['boxes'].float().tolist(),
                                     result['scores'].float().tolist(),
                                     result['text_labels']):
            # The prompt whose words fit the label best; a label that fits
            # prompts of two classes equally is dropped.
            words = set(label.split())
            fits = sorted(((len(words & set(p.split())) /
                            min(len(words) or 1, len(p.split())), p)
                           for p in prompts), reverse=True)
            best = {prompts[p] for fit, p in fits if fit == fits[0][0]}
            if not words or fits[0][0] < 0.5 or len(best) > 1:
                continue
            found.append((best.pop(), score, (box[0] / im.width,
                                              box[1] / im.height,
                                              box[2] / im.width,
                                              box[3] / im.height)))
        return found

    with open(os.path.join(root, 'metadata.csv'), newline='') as f:
        dishes = list(csv.DictReader(f))
    skipped, kept, meat_alone = Counter(), 0, []
    for done, dish in enumerate(dishes):
        grams = {}
        for part in filter(None, dish['ingredients'].split(';')):
            name, weight = part.rsplit(':', 1)
            name = name.strip().lower()
            grams[name] = grams.get(name, 0) + float(weight)
        on_plate = {n: g for n, g in grams.items() if g >= N5K_MIN_GRAMS}
        codes = {N5K_CLASS[n] for n in on_plate if n in N5K_CLASS}
        if set(on_plate) & N5K_UNSURE:
            skipped['a food that may look like ours'] += 1
            continue
        if len(codes & MEATS) > 1:
            # Grounding DINO cannot tell chicken from pork on one plate.
            skipped['two kinds of meat'] += 1
            continue
        if not codes & WEAK:
            skipped['no chicken, pork, beef or greens'] += 1
            continue
        path = os.path.join(root, 'images', dish['dish_id'] + '.png')
        if not os.path.exists(path):
            skipped['no photo'] += 1
            continue
        im = shrunk(path)
        prompts = {N5K_PROMPT.get(n, n): N5K_CLASS[n] for n in on_plate
                   if n in N5K_CLASS}
        seen = detector(im)
        boxes = []
        gd = sorted(grounding(im, prompts), key=lambda d: -d[1])
        for code, score, box in gd:
            if area(box) > MAX_AREA:
                continue
            if code in MEATS:
                if score < BOX_SURE and not any(
                        iou(box, b) >= MEAT_AGREE_IOU for _, _, b in seen):
                    continue
            elif score < BOX_MIN or (score < BOX_SURE and not any(
                    iou(box, b) >= 0.5 for _, _, b in seen)):
                continue
            if any(iou(box, b) > (0.5 if c == code else 0.7)
                   for c, _, b in boxes):
                continue
            boxes.append((code, score, box))

        # A box around several others is the whole plate, not a food.
        def inside(b, outer):
            cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
            return outer[0] <= cx <= outer[2] and outer[1] <= cy <= outer[3]
        boxes = [d for d in boxes if area(d[2]) < 0.25 or
                 sum(inside(o[2], d[2]) for o in boxes if o is not d) < 2]
        meat = next(iter(codes & MEATS), None)
        for code, score, box in seen:
            # A food the detector is sure of and the prompts missed, if the
            # plate holds it: a meat is the plate's meat.
            if code in ANY_MEAT and meat:
                code = meat
            if (score >= TEACHER_SURE and code in codes and
                    all(iou(box, b) < 0.3 for _, _, b in boxes)):
                boxes.append((code, score, box))
        if meat and sum(g for n, g in on_plate.items()
                        if N5K_CLASS.get(n) == meat) >= N5K_MEAT_GRAMS \
                and not any(c == meat for c, _, _ in boxes):
            alone = next((d for d in gd if d[0] == meat and
                          MEAT_ALONE_AREA[0] <= area(d[2]) <= MEAT_ALONE_AREA[1]
                          and all(MEAT_ALONE_EDGE <= (d[2][i] + d[2][i + 2]) / 2
                                  <= 1 - MEAT_ALONE_EDGE for i in (0, 1))),
                         None)
            if not alone:
                skipped['its meat not found'] += 1
                continue
            boxes.append(alone)
            meat_alone.append(f'n5k_{len(writer.rows):06d}')
        weighed = {N5K_CLASS[n] for n, g in on_plate.items()
                   if n in N5K_CLASS and g >= N5K_MEAT_GRAMS}
        if not boxes or (weighed & WEAK) - {c for c, _, _ in boxes}:
            # Greens weighed but not boxed would be learned as background.
            skipped['no box, or its greens not found'] += 1
            if meat_alone and meat_alone[-1] == f'n5k_{len(writer.rows):06d}':
                meat_alone.pop()
            continue
        writer.save('n5k', im, [(c, *b) for c, _, b in boxes], dish['dish_id'])
        kept += 1
        if done % 200 == 199:
            print(f'Nutrition5k: {done + 1} of {len(dishes)} dishes, {kept} '
                  'kept', flush=True)
    card.append(f'- Nutrition5k: {kept} photos of {len(dishes)} dishes; left '
                f'out: {dict(skipped)}; {GD_MODEL}; on {len(meat_alone)} the '
                "meat box is Grounding DINO's alone (meat_alone.txt)")
    with open(os.path.join(writer.dir, 'meat_alone.txt'), 'w') as f:
        f.write(''.join(name + '\n' for name in meat_alone))
    print(card[-1], flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fr22')
    parser.add_argument('--n5k')
    parser.add_argument('--teacher')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    if args.n5k and not args.teacher:
        parser.error('--n5k needs --teacher')
    writer, card = Writer(args.out), []
    detector = load_detector(args.teacher) if args.teacher else None
    if detector:
        card.append('- Checked by the detector '
                    f'{os.path.basename(args.teacher)}')
    if args.fr22:
        fr22(args.fr22, writer, card, detector)
    if args.n5k:
        n5k(args.n5k, writer, card, detector)

    with open(os.path.join(writer.dir, 'sources.csv'), 'w', newline='',
              encoding='utf-8') as f:
        csv.writer(f).writerows([('name', 'source', 'photo'), *writer.rows])
    # The card goes in the zip too: train_detector.ipynb finds the folder
    # by it where Kaggle has unzipped the dataset.
    lines = ['# Plates card', '', f'- Made: {date.today().isoformat()}', *card,
             f'- Photos: {len(writer.rows)}', '',
             '| class | MyFoodRepo boxes | Nutrition5k boxes |', '|---|---|---|']
    lines += [f'| {c} | {writer.boxes[("fr22", c)]} | {writer.boxes[("n5k", c)]} |'
              for c in CLASSES]
    text = '\n'.join(lines) + '\n'
    for folder in (writer.dir, args.out):
        with open(os.path.join(folder, 'PLATES_CARD.md'), 'w',
                  encoding='utf-8') as f:
            f.write(text)
    print(text)
    path = os.path.join(args.out, 'plates.zip')
    with zipfile.ZipFile(path + '.part', 'w', zipfile.ZIP_STORED) as z:
        for folder, _, files in os.walk(writer.dir):
            for name in sorted(files):
                full = os.path.join(folder, name)
                z.write(full, os.path.relpath(full, writer.dir))
    os.replace(path + '.part', path)
    print(f'{path}: {os.path.getsize(path) / 1e6:.0f} MB')
    # The same without the photos, small enough to upload from a browser:
    # train_detector.ipynb then takes them from the original datasets.
    path = os.path.join(args.out, 'plates_labels.zip')
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for folder, _, files in os.walk(writer.dir):
            for name in sorted(files):
                full = os.path.join(folder, name)
                rel = os.path.relpath(full, writer.dir)
                if not rel.startswith('images'):
                    z.write(full, rel)
    print(f'{path}: {os.path.getsize(path) / 1e6:.1f} MB')

    rng = random.Random(SEED)
    tiles = []
    for name, _, _ in rng.sample(writer.rows, min(24, len(writer.rows))):
        im = Image.open(os.path.join(writer.dir, 'images', 'train', name + '.jpg'))
        im.thumbnail((320, 320))
        draw = ImageDraw.Draw(im)
        with open(os.path.join(writer.dir, 'labels', 'train', name + '.txt')) as f:
            for line in f:
                c, cx, cy, w, h = line.split()
                cx, cy, w, h = (float(v) for v in (cx, cy, w, h))
                box = ((cx - w / 2) * im.width, (cy - h / 2) * im.height,
                       (cx + w / 2) * im.width, (cy + h / 2) * im.height)
                draw.rectangle(box, outline=(255, 40, 40), width=2)
                draw.text((box[0] + 3, box[1] + 2), CLASSES[int(c)],
                          fill=(255, 255, 0))
        tiles.append(im)
    if tiles:
        grid = Image.new('RGB', (6 * 320, (len(tiles) + 5) // 6 * 320), 'white')
        for i, tile in enumerate(tiles):
            grid.paste(tile, (i % 6 * 320, i // 6 * 320))
        grid.save(os.path.join(args.out, 'preview.jpg'), quality=85)


if __name__ == '__main__':
    main()
