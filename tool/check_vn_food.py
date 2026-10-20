"""Checks assets/data/vn_food/*.csv against docs/MODEL_CONTRACT.md.

Run from the project root:
    python tool/check_vn_food.py            # report errors and progress
    python tool/check_vn_food.py --strict   # also fail while values are missing

It never fills in numbers: every nutrition value must come from a cited source.
"""
import ast
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets' / 'data' / 'vn_food'
CONTRACT = ROOT / 'docs' / 'MODEL_CONTRACT.md'
NOTEBOOK = ROOT / 'tool' / 'train' / 'train_food_model.py'
COMPONENT_HEADER = ['code', 'name_vi', 'name_en', 'kcal_per_100g', 'protein_g',
                    'carb_g', 'fat_g', 'unit_name_vi', 'unit_grams', 'source']
DISH_HEADER = ['dish', 'component', 'default_grams', 'default_units']
NAME_HEADER = ['code', 'name_vi', 'name_en']
PLAN_HEADER = ['code', 'kind', 'slots', 'goals', 'note']
DISH_KINDS = {'dish', 'combo', 'soup'}
COMPONENT_KINDS = {'staple', 'main', 'side'}
SLOTS = {'breakfast', 'lunch', 'dinner', 'snack'}
GOALS = {'lose', 'maintain', 'gain'}
NUTRIENTS = ['kcal_per_100g', 'protein_g', 'carb_g', 'fat_g']


def contract_codes(section):
    """First `code` of each table row in contract section `section`."""
    text = CONTRACT.read_text(encoding='utf-8')
    match = re.search(rf'^## {section}\..*?(?=^## )', text, re.M | re.S)
    if not match:
        sys.exit(f'Section {section} not found in {CONTRACT}')
    codes = []
    for line in match.group(0).splitlines():
        if line.startswith('|'):
            found = re.search(r'`([a-z0-9_]+)`', line)
            if found:
                codes.append(found.group(1))
    return codes


def read(path, header):
    with path.open(encoding='utf-8', newline='') as file:
        reader = csv.DictReader(file)
        if reader.fieldnames != header:
            sys.exit(f'{path.name}: header must be {",".join(header)}')
        return list(reader)


def number(value):
    try:
        result = float(value)
    except ValueError:
        return None
    return result if result == result and result >= 0 else None


def main():
    # Windows consoles default to a legacy code page that has no Vietnamese.
    sys.stdout.reconfigure(encoding='utf-8')
    strict = '--strict' in sys.argv
    errors, missing = [], []
    dishes = contract_codes(2)
    contract_components = set(contract_codes(3))

    components = read(DATA / 'components.csv', COMPONENT_HEADER)
    codes = [row['code'] for row in components]
    for code in sorted({c for c in codes if codes.count(c) > 1}):
        errors.append(f'components.csv: duplicate code {code}')
    for code in sorted(contract_components - set(codes)):
        errors.append(f'components.csv: missing contract component {code}')
    for code in codes:
        if code not in contract_components and not code.startswith('_base_'):
            errors.append(f'components.csv: {code} is not in the contract')

    filled = 0
    for row in components:
        code = row['code']
        values = {key: row[key].strip() for key in NUTRIENTS}
        if not any(values.values()):
            missing.append(f'{code}: nutrition')
            continue
        parsed = {key: number(value) for key, value in values.items()}
        bad = [key for key, value in parsed.items() if value is None]
        if bad:
            errors.append(f'{code}: {", ".join(bad)} must be numbers >= 0')
            continue
        if not row['source'].strip():
            errors.append(f'{code}: source is required for its nutrition values')
        kcal = parsed['kcal_per_100g']
        if kcal > 900:
            errors.append(f'{code}: {kcal} kcal/100 g is above pure fat')
        mass = parsed['protein_g'] + parsed['carb_g'] + parsed['fat_g']
        if mass > 100:
            errors.append(f'{code}: protein + carb + fat exceed 100 g per 100 g')
        energy = 4 * parsed['protein_g'] + 4 * parsed['carb_g'] + 9 * parsed['fat_g']
        if kcal >= 40 and abs(energy - kcal) > 0.25 * kcal:
            errors.append(f'{code}: macros give {energy:.0f} kcal but the row '
                          f'says {kcal:.0f} (check the source)')
        if row['unit_grams'].strip() and number(row['unit_grams']) in (None, 0):
            errors.append(f'{code}: unit_grams must be a positive number')
        if row['unit_name_vi'].strip() and not row['unit_grams'].strip():
            missing.append(f'{code}: grams per {row["unit_name_vi"]}')
        filled += 1

    names = read(DATA / 'dish_names.csv', NAME_HEADER)
    named = [row['code'] for row in names]
    if named != dishes:
        errors.append('dish_names.csv: codes must list the contract dishes '
                      'in contract order')
    for row in names:
        if not row['name_vi'].strip() or not row['name_en'].strip():
            errors.append(f'dish_names.csv {row["code"]}: both names are required')

    rows = read(DATA / 'dishes.csv', DISH_HEADER)
    known = set(codes)
    defaults = 0
    for row in rows:
        dish, component = row['dish'], row['component']
        where = f'dishes.csv {dish}/{component}'
        if dish not in dishes:
            errors.append(f'{where}: dish is not in the contract')
        if component not in known:
            errors.append(f'{where}: component is not in components.csv')
        if component.startswith('_base_') and component != f'_base_{dish}':
            errors.append(f'{where}: a base row must be _base_{dish}')
        grams, units = row['default_grams'].strip(), row['default_units'].strip()
        if grams and units:
            errors.append(f'{where}: use default_grams or default_units, not both')
        for name, value in (('default_grams', grams), ('default_units', units)):
            if value and number(value) in (None, 0):
                errors.append(f'{where}: {name} must be a positive number')
        if grams or units:
            defaults += 1
        else:
            missing.append(f'{where}: default portion')
    for dish in dishes:
        if not any(row['dish'] == dish for row in rows):
            missing.append(f'{dish}: no components in dishes.csv')

    # meal_plan.csv: what the meal planner may suggest, for which meal and goal.
    plan = read(DATA / 'meal_plan.csv', PLAN_HEADER)
    seen = set()
    nourishing = {row['code'] for row in components
                  if all(row[key].strip() for key in NUTRIENTS)}
    for row in plan:
        code, kind = row['code'], row['kind']
        where = f'meal_plan.csv {code}'
        if code in seen:
            errors.append(f'{where}: listed twice')
        seen.add(code)
        if kind in DISH_KINDS:
            if code not in dishes:
                errors.append(f'{where}: {kind} must be a contract dish')
        elif kind in COMPONENT_KINDS:
            if code not in nourishing:
                errors.append(f'{where}: {kind} must be a component with nutrition')
        else:
            errors.append(f'{where}: unknown kind {kind}')
        for name, allowed in (('slots', SLOTS), ('goals', GOALS)):
            values = [v for v in row[name].split('|') if v]
            if not values or any(v not in allowed for v in values):
                errors.append(f'{where}: {name} must be from {sorted(allowed)}')

    # The training notebook carries its own copy of the dish list and each
    # dish's recipe components (it runs on Kaggle without this repository).
    notebook = {}
    for node in ast.parse(NOTEBOOK.read_text(encoding='utf-8')).body:
        if (isinstance(node, ast.Assign) and len(node.targets) == 1 and
                getattr(node.targets[0], 'id', None) in ('DISHES', 'DISH_PARTS')):
            notebook[node.targets[0].id] = ast.literal_eval(node.value)
    if notebook.get('DISHES') != dishes:
        errors.append('train_food_model.py: DISHES must list the contract '
                      'dishes in contract order')
    recipe = {}
    for row in rows:
        if not row['component'].startswith('_base_'):
            recipe.setdefault(row['dish'], []).append(row['component'])
    for dish in dishes:
        if tuple(notebook.get('DISH_PARTS', {}).get(dish, ())) != tuple(
                recipe.get(dish, ())):
            errors.append(f'train_food_model.py: DISH_PARTS[{dish!r}] must be '
                          f'{tuple(recipe.get(dish, ()))}, as in dishes.csv')

    print(f'Components with nutrition: {filled}/{len(components)}')
    print(f'Dish rows with a default portion: {defaults}/{len(rows)}')
    for error in errors:
        print(f'ERROR   {error}')
    if strict:
        for item in missing:
            print(f'MISSING {item}')
    elif missing:
        print(f'{len(missing)} values still to fill (use --strict to list them).')
    if errors or (strict and missing):
        sys.exit(1)
    print('OK')


if __name__ == '__main__':
    main()
