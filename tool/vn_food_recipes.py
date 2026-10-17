"""Computes per-100 g nutrition of mixed components from their recipes.

Run from the project root:
    python tool/vn_food_recipes.py           # print the results
    python tool/vn_food_recipes.py --write   # also update components.csv

Each ingredient uses a value from the National Institute of Nutrition food
lookup (viendinhduong.vn, Vietnamese food composition codes). A recipe sums
its ingredients and divides by the cooked yield, so water lost while cooking
concentrates the nutrients. Yields are the recipe's estimates, not weighed
batches; re-run with measured yields once they exist.
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / 'assets' / 'data' / 'vn_food' / 'components.csv'

# code: (name, kcal, protein, carb, fat) per 100 g.
NIN = {
    '1017': ('Bột gạo tẻ', 360, 6.6, 82.6, 0.4),
    '2015': ('Miến dong khô', 338, 0.6, 83.7, 0.1),
    '4007': ('Cà rốt tươi', 44, 1.5, 9.03, 0.17),
    '4033': ('Đu đủ xanh', 30, 0.8, 6.6, 0),
    '4036': ('Giá đậu xanh', 52, 5.5, 7.17, 0.13),
    '4037': ('Hành củ', 29, 1.3, 5.22, 0.28),
    '4038': ('Hành lá', 26, 1.3, 5.2, 0),
    '4103': ('Tỏi ta', 126, 6, 24.65, 0.35),
    '4125': ('Mộc nhĩ khô', 332, 10.6, 72, 0.2),
    '5003': ('Chanh', 29, 0.9, 5.96, 0.14),
    '5046': ('Quất (tắc)', 42, 0.9, 9.6, 0),
    '6002': ('Dầu thảo mộc', 897, 0, 0, 99.7),
    '7018': ('Thịt lợn nửa nạc nửa mỡ', 260, 16.5, 0, 21.5),
    '9012': ('Trứng gà công nghiệp', 132, 12.79, 1.89, 8.17),
    '12014': ('Đường kính', 397, 0, 99.3, 0),
    '13004': ('Hạt tiêu', 365, 7, 67.6, 7.4),
    '13005': ('Muối', 1, 0, 0, 0),
    '13006': ('Bột nghệ', 380, 7.83, 64.91, 9.88),
    '13017': ('Nước mắm cá', 35, 5.06, 3.64, 0.01),
    '13034': ('Giấm ăn', 21, 0, 0.93, 0),
    '13039': ('Ớt tươi', 18, 1.4, 2.6, 0.2),
    '13046': ('Bột năng', 343, 0.7, 85.1, 0),
    '14006': ('Nước dừa tươi', 21, 0.4, 4.7, 0.1),
    'water': ('Nước lọc', 0, 0, 0, 0),
}

DMX = 'https://www.dienmayxanh.com/vao-bep/'
# code: (ingredient grams, cooked yield in grams, recipe URL, note).
RECIPES = {
    '_base_com_tam': (
        {'13017': 250, '12014': 250, '14006': 500, '5046': 15, '13039': 10},
        975, DMX + 'cach-lam-nuoc-mam-an-com-tam-chua-ngot-ngon-nhu-ngoai-hang-13947',
        'bỏ 60 g thơm sau khi nấu'),
    '_base_bun_cha': (
        {'water': 500, '13017': 120, '13034': 100, '12014': 100, '4033': 150,
         '4007': 80, '4103': 15, '13039': 10},
        1055, DMX + 'cach-lam-nuoc-cham-bun-cha-thom-lung-an-sieu-ngon-don-gian-14271',
        'gồm đu đủ và cà rốt ngâm'),
    '_base_bun_thit_nuong': (
        {'water': 200, '13017': 120, '12014': 100, '5003': 50, '4103': 25,
         '13039': 15},
        500, DMX + 'cach-lam-nuoc-mam-an-bun-thit-nuong-chua-ngot-ngon-nhu-ngoai-13905',
        ''),
    'mo_hanh': (
        {'4038': 100, '6002': 180, '13005': 3, '12014': 2},
        283, DMX + '2-cach-lam-mo-hanh-tuoi-xanh-thom-ngon-beo-ngay-ngot-vi-don-06904',
        'bản không tóp mỡ'),
    'cha_trung': (
        # Cách 2 of the article: 5 eggs at 50 g, and 20 g of seasoning split
        # into oil and annatto oil, fish sauce, salt and pepper.
        {'9012': 250, '7018': 150, '4125': 15, '2015': 10, '4037': 20,
         '6002': 10, '13017': 8, '13005': 1, '13004': 1},
        540, DMX + 'cach-lam-cha-trung-ngon-nhu-ngoai-hang-com-tam-02028',
        'cách 2; thịt băm tính là nửa nạc nửa mỡ; mộc nhĩ và bún ngâm hút nước'),
    '_base_banh_xeo': (
        {'1017': 200, '13046': 50, '14006': 400, '13006': 3, '13005': 4,
         '4038': 20, '4036': 300, '6002': 50},
        835, DMX + 'cach-lam-banh-xeo-mien-nam-bang-chao-chong-dinh-ngon-gion-22298',
        'coi như dầu tráng bám hết vào bánh; mẻ khoảng 6 cái'),
}
# Grams per natural unit, from the recipe batch: bánh xèo makes about 6.
UNITS = {'_base_banh_xeo': 835 / 6}


def per_100g(ingredients, cooked):
    totals = [0.0, 0.0, 0.0, 0.0]
    for code, grams in ingredients.items():
        for i, value in enumerate(NIN[code][1:]):
            totals[i] += value * grams / 100
    return [round(total * 100 / cooked, 2) for total in totals]


def source(code):
    ingredients, cooked, url, note = RECIPES[code]
    codes = ', '.join(c for c in ingredients if c != 'water')
    text = (f'Tính theo công thức {url}, thành phẩm ước tính {cooked} g; '
            f'nguyên liệu theo Viện Dinh dưỡng mã {codes}')
    return f'{text}; {note}' if note else text


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    results = {code: per_100g(r[0], r[1]) for code, r in RECIPES.items()}
    for code, (kcal, protein, carb, fat) in results.items():
        print(f'{code:22} {kcal:7.1f} kcal  P {protein:5.2f}  C {carb:5.2f}  F {fat:5.2f}')
    if '--write' not in sys.argv:
        return
    with COMPONENTS.open(encoding='utf-8', newline='') as file:
        rows = list(csv.DictReader(file))
    header = list(rows[0].keys())
    for row in rows:
        code = row['code']
        if code in results:
            row.update(zip(['kcal_per_100g', 'protein_g', 'carb_g', 'fat_g'],
                           (f'{value:g}' for value in results[code])))
            row['source'] = source(code)
            if code in UNITS:
                row['unit_grams'] = f'{UNITS[code]:.0f}'
    with COMPONENTS.open('w', encoding='utf-8', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=header, lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)
    print(f'Updated {len(results)} rows in {COMPONENTS.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
