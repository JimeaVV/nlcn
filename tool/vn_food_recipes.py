"""Computes per-100 g nutrition of mixed components from their recipes.

Run from the project root:
    python tool/vn_food_recipes.py           # print the results
    python tool/vn_food_recipes.py --write   # also update components.csv

Ingredients use the National Institute of Nutrition food lookup
(viendinhduong.vn, Vietnamese food composition codes), or USDA FoodData
Central for foods it lacks (keys starting with "fdc"). A recipe sums its
ingredients and divides by the cooked yield, so water lost while cooking
concentrates the nutrients. Yields are the recipe's estimates, not weighed
batches; re-run with measured yields once they exist.

Bone broths cannot be computed from their recipes, because the fat and
gelatin the bones release are unknown. They start from a ready-to-serve
USDA broth and add the seasonings that stay in the pot, so they are low
estimates.
"""
import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / 'assets' / 'data' / 'vn_food' / 'components.csv'

# code: (name, kcal, protein, carb, fat) per 100 g.
FOODS = {
    '1010': ('Bánh đa nem (bánh tráng)', 335, 4, 79.4, 0.2),
    '1017': ('Bột gạo tẻ', 360, 6.6, 82.6, 0.4),
    '2008002': ('Khoai lang luộc', 122, 0.78, 29.22, 0.2),
    '2010': ('Khoai môn', 113, 1.5, 26.4, 0.2),
    '2015': ('Miến dong khô', 338, 0.6, 83.7, 0.1),
    '3001': ('Cùi dừa già', 385, 4.8, 10.4, 36),
    '3017': ('Lạc hạt khô', 583, 27.5, 18, 44.5),
    '3033': ('Tào phớ', 46, 3.8, 4.7, 1.2),
    '4005': ('Cà chua', 24, 0.6, 4.77, 0.23),
    '4007': ('Cà rốt tươi', 44, 1.5, 9.03, 0.17),
    '4033': ('Đu đủ xanh', 30, 0.8, 6.6, 0),
    '4036': ('Giá đậu xanh', 52, 5.5, 7.17, 0.13),
    '4026': ('Dọc mùng', 13, 0.4, 2.8, 0),
    '4037': ('Hành củ', 29, 1.3, 5.22, 0.28),
    '4038': ('Hành lá', 26, 1.3, 5.2, 0),
    '4039': ('Hành tây', 45, 1.8, 9.29, 0.11),
    '4055002': ('Mướp đắng luộc', 21, 0.91, 4.14, 0.1),
    '4075': ('Rau húng', 34, 2.2, 5.08, 0.52),
    '4103': ('Tỏi ta', 126, 6, 24.65, 0.35),
    '4125': ('Mộc nhĩ khô', 332, 10.6, 72, 0.2),
    '5003': ('Chanh', 29, 0.9, 5.96, 0.14),
    '5014': ('Dứa ta', 32, 0.8, 7.3, 0),
    '5030': ('Mít mật', 67, 1.5, 15.2, 0),
    '5035': ('Nhãn', 52, 0.9, 12, 0),
    '5046': ('Quất (tắc)', 42, 0.9, 9.6, 0),
    '6002': ('Dầu thảo mộc', 897, 0, 0, 99.7),
    '3010': ('Đậu xanh hạt khô', 346, 23.4, 57.8, 2.4),
    '7018': ('Thịt lợn nửa nạc nửa mỡ', 260, 16.5, 0, 21.5),
    '7018002': ('Thịt lợn nửa nạc nửa mỡ, luộc', 220, 13.98, 0, 18.22),
    '7034002': ('Dạ dày lợn luộc', 106, 18.25, 0, 3.63),
    '7046': ('Lòng lợn (ruột già)', 167, 6.9, 0.8, 15.1),
    '8022': ('Cá quả (cá lóc)', 97, 18.2, 0, 2.7),
    '8034': ('Cua đồng', 87, 12.3, 2, 3.3),
    '8051': ('Tôm biển', 82, 17.6, 0.9, 0.9),
    '8053': ('Tôm biển khô', 347, 75.6, 2.5, 3.8),
    '9007': ('Trứng chim cút', 157, 12.78, 2.89, 10.47),
    '9012': ('Trứng gà công nghiệp', 132, 12.79, 1.89, 8.17),
    '12014': ('Đường kính', 397, 0, 99.3, 0),
    '13003': ('Gừng tươi', 41, 0.4, 8.59, 0.51),
    '13004': ('Hạt tiêu', 365, 7, 67.6, 7.4),
    '13005': ('Muối', 1, 0, 0, 0),
    '13006': ('Bột nghệ', 380, 7.83, 64.91, 9.88),
    '13011': ('Mắm tôm đặc', 73, 14.8, 0, 1.5),
    '13017': ('Nước mắm cá', 35, 5.06, 3.64, 0.01),
    '13013': ('Mắm tép chua', 68, 8.7, 5.5, 1.2),
    '13020': ('Tương nếp', 86, 4.3, 15.7, 0.7),
    '13022': ('Xì dầu', 55, 6.3, 7.46, 0.04),
    '13034': ('Giấm ăn', 21, 0, 0.93, 0),
    '13039': ('Ớt tươi', 18, 1.4, 2.6, 0.2),
    '13046': ('Bột năng', 343, 0.7, 85.1, 0),
    '14006': ('Nước dừa tươi', 21, 0.4, 4.7, 0.1),
    'water': ('Nước lọc', 0, 0, 0, 0),
    'fdc171538': ('Beef broth, canned, ready-to-serve', 7, 1.14, 0.04, 0.22),
    'fdc174536': ('Chicken broth, ready-to-serve', 6, 0.64, 0.44, 0.21),
    # Contract 1.4 dishes.
    '1018': ('Bột mì trắng', 347, 11, 73.2, 1.1),
    '4043': ('Hoa chuối', 28, 1.5, 5.5, 0),
    '7077': ('Xúc xích', 535, 27.2, 0, 47.4),
    '8033': ('Cua bể', 103, 17.5, 7, 0.6),
    '13023': ('Sốt mayonnaise', 701, 0, 0.1, 77.8),
    'fdc169737': ('Pasta, cooked, enriched, without added salt', 158, 5.8, 30.9, 0.93),
    'fdc171401': ('Lard', 902, 0, 0, 100),
    'fdc171606': ('Fish broth', 16, 2.0, 0.4, 0.6),
    'fdc2706550': ('Fish, cake or patty', 212, 13.63, 10.4, 12.64),
    'fdc2709822': ('Lettuce, salad with assorted vegetables, no dressing', 24, 1.07, 4.58, 0.2),
}
BEEF, CHICKEN, FISH = 'fdc171538', 'fdc174536', 'fdc171606'


def broth(base, cooked, seasonings):
    """[seasonings] plus enough ready-made [base] broth to reach [cooked]."""
    return {base: cooked - sum(seasonings.values()), **seasonings}


def scaled(ingredients, factor):
    return {code: grams * factor for code, grams in ingredients.items()}


# Peanut dipping sauce for gỏi cuốn: 295 g per batch.
PEANUT_SAUCE = {'13020': 100, '3017': 33, 'water': 120, '6002': 25,
                '4103': 12, '12014': 15, '13039': 5}

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
        'cách 2; thịt băm tính là nửa nạc nửa mỡ; mộc nhĩ và bún ngâm hút nước; '
        '1 miếng = 50 g (nhóm ước lượng)'),
    '_base_banh_xeo': (
        {'1017': 200, '13046': 50, '14006': 400, '13006': 3, '13005': 4,
         '4038': 20, '4036': 300, '6002': 50},
        835, DMX + 'cach-lam-banh-xeo-mien-nam-bang-chao-chong-dinh-ngon-gion-22298',
        'coi như dầu tráng bám hết vào bánh; mẻ khoảng 6 cái'),
    '_base_pho_bo': (
        broth(BEEF, 2800, {'13017': 25, '12014': 15, '13005': 12}),
        2800, DMX + 'cach-nau-pho-bo-ha-noi-chuan-vi-nuoc-dung-ngot-thanh-don-gian-22475',
        'ước tính thấp: nước dùng xương bò USDA cộng gia vị nêm'),
    '_base_pho_ga': (
        broth(CHICKEN, 3100, {'13017': 40, '12014': 18, '13005': 16}),
        3100, DMX + 'cach-nau-pho-ga-ha-noi-thom-ngon-chuan-vi-truyen-thong-cuc-23936',
        'ước tính thấp: nước dùng gà USDA cộng gia vị nêm'),
    '_base_bun_bo_hue': (
        broth(BEEF, 3600, {'13011': 40, '13017': 60, '6002': 25, '13039': 20,
                           '12014': 30, '13005': 16, '4103': 30, '4037': 30}),
        3600, DMX + 'cach-nau-bun-bo-hue-dam-da-dung-vi-cho-bua-sang-ngay-tet-00541',
        'ước tính thấp: nước dùng xương USDA cộng mắm ruốc, dầu điều, gia vị'),
    '_base_bun_rieu': (
        broth(BEEF, 4000, {'8034': 215, '9012': 50, '4005': 350, '4037': 40,
                           '4103': 15, '13011': 20, '13017': 35, '12014': 40,
                           '13005': 15, '6002': 25}),
        4000, DMX + 'cach-nau-bun-rieu-cua-dong-ngon-kho-cuong-an-la-ghien-ngay-15299',
        'ước tính thấp: nước dùng xương USDA cộng riêu cua (tính như cua đồng), '
        'trứng, cà chua, gia vị'),
    '_base_hu_tieu': (
        broth(BEEF, 2950, {'13017': 35, '12014': 30, '13005': 12}),
        2950, DMX + 'cach-nau-hu-tieu-mi-nguoi-hoa-thom-ngon-dam-da-la-mieng-don-08607',
        'ước tính thấp: nước dùng xương USDA cộng gia vị nêm'),
    '_base_mi_quang': (
        broth(CHICKEN, 1075, {'14006': 500, '6002': 15, '4037': 50, '4039': 60,
                              '13006': 8, '13017': 30, '12014': 20, '13005': 8}),
        1075, DMX + 'cach-nau-mi-quang-ga-mien-trung-dung-vi-thom-ngon-dam-da-cho-00046',
        'ước tính thấp: nước gà USDA cộng nước dừa, dầu điều, hành nén, gia vị'),
    '_base_banh_canh': (
        broth(BEEF, 2150, {'13017': 25, '12014': 15, '13005': 12}),
        2150, DMX + 'huong-dan-chi-tiet-cach-nau-banh-canh-thom-ngon-tai-nha-01025',
        'ước tính thấp: nước dùng xương USDA cộng gia vị nêm'),
    '_base_bo_kho': (
        {'14006': 1500, '6002': 25, '4037': 35, '13017': 25, '13046': 20,
         'water': 60},
        1375, DMX + 'cach-nau-bo-kho-banh-mi-dam-da-doi-vi-cho-nhung-ngay-chan-com-010087',
        'ước tính thấp: chưa tính gói xốt bò kho 90 g và mỡ bò tiết ra'),
    # One roll: a 15 g medium rice paper (USDA FNDDS 2708166 portion) and an
    # assumed 15 g spoon of peanut sauce.
    '_base_goi_cuon': (
        {'1010': 15, **scaled(PEANUT_SAUCE, 15 / 295)},
        30, DMX + 'tong-hop-4-loai-nuoc-cham-goi-cuon-thom-ngon-dam-da-de-thuc-02901',
        '1 cuốn = 1 bánh tráng 15 g (USDA FNDDS 2708166) và 15 g tương đậu phộng '
        '(giả định 1 muỗng canh)'),
    # VinaFood21 dishes without a usable table entry: recipes estimated by
    # the team (no URL), cooked yields included.
    '_base_tau_hu': (
        {'3033': 200, '12014': 35, '13003': 5, 'water': 20},
        260, None, 'tào phớ với nước đường gừng'),
    '_base_pha_lau': (
        {'7034002': 200, '7046': 200, '14006': 400, '3001': 50, '6002': 15,
         '12014': 10, '13017': 15, '4103': 10},
        750, None, 'lòng heo hầm nước dừa; cùi dừa thay cho nước cốt dừa'),
    '_base_banh_can': (
        {'1017': 100, 'water': 150, '9007': 50, '6002': 5, '4038': 5},
        280, None, 'mẻ khoảng 12 cái, mỗi cái có trứng cút'),
    '_base_banh_trang_tron': (
        {'1010': 50, '9007': 30, '3017': 10, '6002': 10, '8053': 5,
         '4075': 5, '5046': 10, '12014': 5},
        120, None, 'bánh tráng, trứng cút, đậu phộng, sa tế, tôm khô, rau răm'),
    '_base_bot_chien': (
        {'1017': 150, '13046': 50, 'water': 300, '9012': 100, '6002': 30,
         '4038': 10},
        560, None, 'bột hấp cắt miếng chiên với trứng'),
    '_base_ca_ri': (
        {'14006': 500, '3001': 100, 'water': 500, '2008002': 300, '6002': 20,
         '13006': 10, '12014': 10, '13017': 20, '4037': 20},
        1300, None, 'nước cà ri có khoai lang, chưa tính thịt gà; cùi dừa thay '
        'cho nước cốt dừa, bột nghệ thay cho bột cà ri'),
    '_base_canh_khoai_mo': (
        {'2010': 300, '7018': 100, '4038': 10, '13017': 20, 'water': 1000},
        1350, None, 'khoai môn thay cho khoai mỡ, có thịt băm'),
    '_base_canh_kho_qua': (
        {'4055002': 300, '7018': 200, '4125': 5, '2015': 10, '13017': 20,
         'water': 1000},
        1500, None, 'khổ qua nhồi thịt băm, mộc nhĩ, miến'),
    '_base_goi_ga': (
        {'13017': 30, '12014': 30, '5003': 30, '4103': 10, '13039': 5,
         '6002': 10},
        115, None, 'nước trộn: nước mắm, đường, chanh, tỏi ớt, dầu hành phi'),
    # Contract 1.3 dishes, recipes estimated by the team.
    '_base_banh_khot': (
        {'1017': 100, '3001': 30, 'water': 150, '8051': 50, '6002': 30,
         '4038': 5, '13006': 2},
        320, None, 'bột gạo, cốt dừa, tôm, chiên khuôn; mẻ khoảng 16 cái'),
    '_base_banh_beo': (
        {'1017': 100, '13046': 20, 'water': 300, '8053': 15, '13017': 15,
         '12014': 10},
        420, None, 'bánh hấp, tôm chấy, nước mắm; mỡ hành tính riêng'),
    '_base_cao_lau': (
        {'13022': 15, '6002': 10, '12014': 5, 'water': 30},
        60, None, 'nước sốt rưới; sợi, thịt, rau tính riêng'),
    '_base_bun_dau': (
        {'7018002': 100, '13011': 30, '12014': 10, '5003': 10, '6002': 5},
        155, None, 'thịt chân giò luộc và chén mắm tôm pha cho 1 phần'),
    '_base_bun_mam': (
        broth(BEEF, 3000, {'13013': 150, '7018': 300, '12014': 40,
                           '4103': 20, '4037': 30, '6002': 30}),
        3000, None, 'ước tính thấp: nước dùng xương USDA cộng mắm, thịt heo '
        'quay, gia vị; mắm tép thay cho mắm cá'),
    '_base_ca_kho': (
        {'8022': 300, '12014': 20, '13017': 30, '6002': 15, '4037': 15,
         '13004': 2},
        280, None, 'cá lóc kho tộ; cơm và rau tính riêng'),
    '_base_canh_chua': (
        {'8022': 150, '4005': 100, '5014': 80, '4036': 50, '4026': 60,
         '12014': 20, '13017': 20, 'water': 800},
        1100, None, 'canh chua cá lóc với cà chua, thơm, giá, bạc hà'),
    '_base_che': (
        {'12014': 60, '3001': 40, '13046': 30, '5035': 50, '5030': 50,
         '3010': 30, 'water': 250},
        450, None, 'chè thập cẩm: nước đường, cốt dừa, trân châu, nhãn, mít, '
        'đậu xanh'),
    # Contract 1.4 dishes, recipes estimated by the team.
    '_base_banh_trang_nuong': (
        {'1010': 20, '9007': 25, '4038': 5, '8053': 3, '7077': 15,
         '13023': 8, '6002': 2},
        70, None, 'bánh tráng, 2 trứng cút, hành lá, tôm khô, xúc xích, sốt '
        'mayonnaise; 1 cái = 70 g'),
    '_base_banh_pia': (
        {'1018': 35, 'fdc171401': 12, '3010': 20, '12014': 18, '9012': 5,
         'water': 20},
        100, None, 'vỏ bột mì và mỡ heo; nhân đậu xanh, đường, trứng; chưa '
        'tính sầu riêng; 1 cái = 100 g'),
    '_base_bun_ca': (
        broth(FISH, 3000, {'fdc2706550': 400, '4005': 300, '13017': 40,
                           '12014': 20, '13005': 15, '6002': 20, '4037': 30}),
        3000, None, 'ước tính thấp: nước dùng cá USDA cộng chả cá, cà chua, '
        'gia vị; bún, cá và rau tính riêng'),
    '_base_salad': (
        {'fdc2709822': 150, '13023': 15},
        165, None, 'rau trộn có cà chua, cà rốt với 15 g sốt mayonnaise'),
    '_base_nui_xao_bo': (
        {'fdc169737': 200, '6002': 10, '4039': 30, '4005': 40, '13022': 10,
         '12014': 3},
        280, None, 'nui luộc xào hành tây, cà chua, xì dầu; thịt bò tính riêng'),
    '_base_sup_cua': (
        broth(CHICKEN, 1500, {'8033': 150, '9012': 100, '13046': 45,
                              '4038': 10, '13017': 15, '13005': 6, '13004': 1}),
        1500, None, 'ước tính thấp: nước gà USDA cộng thịt cua (tính như cua '
        'bể), trứng, bột năng'),
    '_base_nom_hoa_chuoi': (
        {'4043': 200, '4007': 30, '4075': 10, '3017': 20, '13017': 15,
         '12014': 15, '5003': 15, '4103': 5, '13039': 3},
        310, None, 'hoa chuối, cà rốt, rau thơm, lạc rang, nước trộn; chưa tính '
        'thịt gà hay tai heo'),
}
# Grams per natural unit: bánh xèo makes about 6 per batch, gỏi cuốn is the
# 30 g roll above, and the team estimated a slice of chả trứng.
UNITS = {'_base_banh_xeo': 835 / 6, '_base_goi_cuon': 30, 'cha_trung': 50,
         '_base_banh_can': 280 / 12, '_base_banh_khot': 320 / 16,
         '_base_banh_trang_nuong': 70, '_base_banh_pia': 100}


def per_100g(ingredients, cooked):
    totals = [0.0, 0.0, 0.0, 0.0]
    for code, grams in ingredients.items():
        for i, value in enumerate(FOODS[code][1:]):
            totals[i] += value * grams / 100
    return [round(total * 100 / cooked, 2) for total in totals]


def source(code):
    ingredients, cooked, url, note = RECIPES[code]
    nin = ', '.join(c for c in ingredients if c[0].isdigit())
    usda = ', '.join(c[3:] for c in ingredients if c.startswith('fdc'))
    recipe = url or 'nhóm ước lượng'
    text = (f'Tính theo công thức {recipe}, thành phẩm ước tính {cooked} g; '
            f'nguyên liệu theo Viện Dinh dưỡng mã {nin}')
    if usda:
        text += f' và USDA FoodData Central {usda}'
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
