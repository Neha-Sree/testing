"""
Seed a curated library of pregnancy-friendly meal templates.

Run on every app startup (idempotent): if a template with the same ``slot`` +
``name`` already exists, its tags are refreshed but other fields are preserved.

Coverage:
- All 6 meal slots × all 3 trimesters × veg / vegan / non-veg
- Allergy-free variants for: dairy, gluten, nuts, eggs, fish, soy
- Medical tags: high_iron, high_calcium, low_gi, low_sodium, low_calorie,
  high_calorie, light (morning-sickness), iodine_rich, vitamin_rich, high_protein
- Cuisines: indian, general
"""
from __future__ import annotations

import json
import logging

from sqlalchemy.orm import Session

from .models import MealTemplate

log = logging.getLogger(__name__)


def _t(tags: list[str]) -> str:
    return json.dumps(tags)


# fmt: off
# Each row: (slot, name, description, portion,
#            kcal, protein_g, carbs_g, fat_g, fiber_g, iron_mg, calcium_mg,
#            tags_json, allergens_json, diet_type, cuisine)

_TEMPLATES: list[tuple] = [

    # =========================================================================
    # BREAKFAST
    # =========================================================================

    # T1 – veg – indian – dairy (paratha)
    (
        "breakfast", "Methi Paratha with Curd",
        "Iron-rich fenugreek (methi) whole-wheat paratha with low-fat curd. "
        "Folate from methi supports early neural tube development.",
        "2 paratha + 1 cup curd", 460, 18, 58, 16, 8, 5.5, 290,
        _t(["trimester_1","high_iron","high_calcium","vitamin_rich","high_protein","indian"]),
        _t(["dairy","gluten"]), "veg", "indian",
    ),
    # T1 – veg – general – gluten-free, dairy-free
    (
        "breakfast", "Vegetable Oats Porridge",
        "Heart-healthy oats with diced carrots, peas and a drizzle of olive oil; "
        "gentle on morning sickness.",
        "1 large bowl", 320, 12, 48, 8, 7, 3.2, 180,
        _t(["trimester_1","light","low_gi","low_sodium","high_protein","general"]),
        _t(["gluten"]), "veg", "general",
    ),
    # T1 – veg – indian – gluten-free
    (
        "breakfast", "Idli with Sambar (low-sodium)",
        "Steamed idli with lentil sambar; gentle, easy to digest.",
        "3 idli + sambar", 340, 13, 60, 5, 6, 3.0, 110,
        _t(["trimester_1","light","low_sodium","low_gi","indian"]),
        _t([]), "veg", "indian",
    ),
    # T1 – vegan – general – gluten-free, dairy-free, nut-free
    (
        "breakfast", "Banana & Chia Smoothie Bowl",
        "Ripe banana blended with oat milk, topped with chia seeds and sliced kiwi. "
        "Rich in folate and omega-3 — ideal for the first trimester.",
        "1 bowl", 310, 8, 52, 7, 9, 2.5, 220,
        _t(["trimester_1","light","vitamin_rich","low_gi","general"]),
        _t([]), "vegan", "general",
    ),
    # T1 – veg – general – egg, no gluten
    (
        "breakfast", "Poached Egg on Sweet Potato Toast",
        "Naturally sweet potato slices toasted, topped with a poached egg. "
        "Choline supports early fetal brain development.",
        "2 slices + 1 egg", 380, 20, 42, 14, 5, 3.0, 110,
        _t(["trimester_1","high_protein","vitamin_rich","low_gi","general"]),
        _t(["eggs"]), "veg", "general",
    ),

    # T2 – veg – indian – dairy
    (
        "breakfast", "Spinach & Paneer Paratha with Curd",
        "Whole-wheat paratha stuffed with iron-rich spinach and protein-packed "
        "paneer, served with low-fat curd.",
        "2 paratha + 1 cup curd", 480, 22, 55, 18, 7, 6.0, 350,
        _t(["trimester_2","high_iron","high_calcium","vitamin_rich","high_protein","indian"]),
        _t(["dairy","gluten"]), "veg", "indian",
    ),
    # T2 – veg – indian – gluten-free
    (
        "breakfast", "Ragi Dosa with Coconut Chutney",
        "Calcium-rich ragi (finger millet) dosa, ideal in trimester 2 & 3 "
        "for bone development.",
        "2 dosa + chutney", 380, 12, 60, 10, 5, 3.0, 280,
        _t(["trimester_2","trimester_3","high_calcium","low_gi","light","indian"]),
        _t([]), "veg", "indian",
    ),
    # T2 – vegan – general – soy
    (
        "breakfast", "Tofu Veggie Scramble",
        "Iron- and protein-rich tofu scramble with bell pepper and turmeric.",
        "1 plate", 360, 22, 18, 18, 5, 5.5, 350,
        _t(["trimester_2","trimester_3","high_iron","high_protein","high_calcium","vitamin_rich","general"]),
        _t(["soy"]), "vegan", "general",
    ),
    # T2 – vegan – indian – dairy-free, gluten-free, nut-free, soy-free
    (
        "breakfast", "Moong Dal Cheela with Tomato Chutney",
        "Crispy yellow moong dal pancakes spiced with cumin and ginger. "
        "High in protein and iron, easy on digestion.",
        "3 cheela + chutney", 380, 22, 46, 8, 8, 5.0, 100,
        _t(["trimester_2","high_iron","high_protein","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T2 – veg – general – gluten-free, dairy-free, nut-free
    (
        "breakfast", "Quinoa Vegetable Upma",
        "Protein-packed quinoa cooked with onion, carrot and green peas. "
        "Provides all essential amino acids plus calcium.",
        "1 bowl", 400, 16, 58, 9, 7, 4.5, 180,
        _t(["trimester_2","high_protein","high_calcium","low_gi","general"]),
        _t([]), "vegan", "general",
    ),

    # T3 – non-veg – general – no dairy, nut-free
    (
        "breakfast", "Boiled Eggs with Whole-Grain Toast & Tomato",
        "High-protein, choline-rich breakfast for fetal brain development.",
        "2 eggs + 2 toast", 420, 24, 38, 16, 4, 3.6, 120,
        _t(["trimester_3","high_protein","vitamin_rich","general"]),
        _t(["eggs","gluten"]), "non-veg", "general",
    ),
    # T3 – veg – indian – dairy, gluten-free (ragi)
    (
        "breakfast", "Ragi Mudde with Sambar",
        "Dense ragi (finger millet) balls with vegetable sambar. "
        "Excellent calcium and iron source for the third trimester.",
        "2 mudde + sambar", 450, 14, 72, 8, 10, 5.5, 380,
        _t(["trimester_3","high_calcium","high_iron","low_gi","indian"]),
        _t([]), "veg", "indian",
    ),
    # T3 – vegan – general – allergy-free
    (
        "breakfast", "Avocado & Tomato Rice Cake",
        "Gluten-free rice cakes topped with mashed avocado, cherry tomato "
        "and hemp seeds. Rich in healthy fats for fetal brain growth.",
        "2 rice cakes with toppings", 380, 10, 44, 18, 8, 2.5, 80,
        _t(["trimester_3","high_calorie","vitamin_rich","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – veg – general – dairy (Greek yogurt) – nut-free
    (
        "breakfast", "Greek Yogurt Parfait with Granola & Berries",
        "Calcium-rich Greek yogurt layered with whole-grain granola and "
        "mixed berries. Provides protein, calcium and antioxidants.",
        "1 large bowl", 440, 20, 58, 10, 5, 2.0, 340,
        _t(["trimester_3","high_calcium","high_protein","vitamin_rich","general"]),
        _t(["dairy","gluten"]), "veg", "general",
    ),

    # =========================================================================
    # MID-MORNING SNACK
    # =========================================================================

    # T1 – vegan – general – allergy-free
    (
        "mid_morning", "Mixed Fruit Bowl with Pomegranate",
        "Hydrating fruit bowl rich in vitamin C — helps iron absorption.",
        "1 medium bowl", 180, 3, 42, 1, 6, 1.0, 40,
        _t(["trimester_1","light","vitamin_rich","high_iron","low_gi","general"]),
        _t([]), "vegan", "general",
    ),
    # T1 – vegan – general – allergy-free
    (
        "mid_morning", "Coconut Water with Soaked Chia",
        "Hydrating, mineral-rich and gentle on the stomach.",
        "1 glass + chia", 110, 2, 18, 3, 5, 1.2, 100,
        _t(["trimester_1","light","low_gi","vitamin_rich","general"]),
        _t([]), "vegan", "general",
    ),
    # T1 – vegan – indian – allergy-free
    (
        "mid_morning", "Boiled Sweet Corn with Lemon & Pepper",
        "Fibre-rich sweet corn, easy on nausea, provides folate and vitamin C.",
        "1 medium cob", 140, 4, 28, 2, 4, 1.5, 30,
        _t(["trimester_1","light","low_sodium","vitamin_rich","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T1 – veg – general – dairy (curd)
    (
        "mid_morning", "Low-fat Curd with Flax Seeds",
        "Probiotic curd with flax seeds adds omega-3 and calcium; "
        "helps with nausea.",
        "1 small bowl", 150, 7, 14, 5, 3, 1.0, 220,
        _t(["trimester_1","light","high_calcium","low_gi","general"]),
        _t(["dairy"]), "veg", "general",
    ),

    # T2 – vegan – indian
    (
        "mid_morning", "Sprouts Chaat with Lemon",
        "Iron- and protein-rich mung sprouts, tangy and refreshing.",
        "1 small bowl", 220, 12, 30, 4, 6, 4.5, 90,
        _t(["trimester_2","high_iron","high_protein","low_gi","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T2 – veg – indian – no nuts
    (
        "mid_morning", "Roasted Makhana (Fox Nuts)",
        "Low-calorie, calcium-rich snack — great in second and third trimester.",
        "1 handful", 130, 4, 24, 1, 2, 1.5, 70,
        _t(["trimester_2","trimester_3","light","low_calorie","high_calcium","low_sodium","indian"]),
        _t([]), "veg", "indian",
    ),
    # T2 – vegan – general – nuts
    (
        "mid_morning", "Date & Almond Energy Balls",
        "Naturally sweet, iron- and calcium-dense bites.",
        "2 pieces", 200, 5, 28, 8, 4, 2.2, 140,
        _t(["trimester_2","trimester_3","high_iron","high_calcium","high_calorie","general"]),
        _t(["nuts"]), "vegan", "general",
    ),
    # T2 – vegan – general – nut-free, allergy-free
    (
        "mid_morning", "Pumpkin Seeds & Dried Apricot Mix",
        "Zinc- and iron-rich pumpkin seeds with iron-dense dried apricots. "
        "No common allergens.",
        "1 small handful", 190, 7, 22, 9, 4, 3.5, 60,
        _t(["trimester_2","high_iron","vitamin_rich","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),

    # T3 – vegan – general – allergy-free
    (
        "mid_morning", "Hummus with Carrot & Cucumber Sticks",
        "Protein, fibre and crunch — keeps blood sugar steady.",
        "3 tbsp hummus + veg sticks", 180, 7, 18, 9, 5, 2.0, 60,
        _t(["trimester_3","low_gi","high_protein","light","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – veg – general – dairy
    (
        "mid_morning", "Paneer Cubes with Capsicum & Pepper",
        "High-calcium, high-protein light snack for the third trimester.",
        "80 g paneer + veg", 200, 14, 6, 14, 2, 0.5, 350,
        _t(["trimester_3","high_calcium","high_protein","low_gi","low_sodium","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),
    # T3 – vegan – indian – allergy-free
    (
        "mid_morning", "Roasted Chana (Chickpeas)",
        "Iron-rich, protein-rich crunchy snack.",
        "1 handful", 180, 9, 26, 3, 6, 4.0, 60,
        _t(["trimester_2","trimester_3","high_iron","high_protein","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T3 – non-veg – general – egg
    (
        "mid_morning", "Hard-Boiled Egg with Cucumber Slices",
        "Quick protein hit with choline for fetal brain growth.",
        "1 egg + veg", 130, 9, 4, 8, 1, 1.0, 50,
        _t(["trimester_3","high_protein","low_gi","low_calorie","general"]),
        _t(["eggs"]), "non-veg", "general",
    ),

    # =========================================================================
    # LUNCH
    # =========================================================================

    # T1 – vegan – indian – allergy-free
    (
        "lunch", "Dal Palak with Brown Rice & Salad",
        "Spinach-lentil dal with high-fibre brown rice; iron- and folate-rich.",
        "1 katori dal + 1 cup rice + salad", 540, 22, 80, 10, 11, 6.5, 220,
        _t(["trimester_1","high_iron","high_protein","vitamin_rich","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T1 – veg – indian – allergy-free (light)
    (
        "lunch", "Khichdi with Vegetables & Ghee",
        "Light, easy-to-digest one-pot meal — ideal for nausea or fatigue.",
        "1 large bowl", 420, 15, 65, 9, 7, 4.0, 130,
        _t(["trimester_1","light","low_sodium","high_protein","indian"]),
        _t([]), "veg", "indian",
    ),
    # T1 – veg – general – gluten-free, dairy-free
    (
        "lunch", "Lentil & Vegetable Soup with Quinoa",
        "Iron and protein-rich red lentil soup with quinoa; gentle on digestion.",
        "1 large bowl + quinoa", 460, 22, 68, 7, 12, 6.0, 140,
        _t(["trimester_1","high_iron","high_protein","low_sodium","light","general"]),
        _t([]), "vegan", "general",
    ),
    # T1 – non-veg – general – gluten-free
    (
        "lunch", "Lemon-Herb Chicken with Brown Rice",
        "Lean grilled chicken marinated with lemon and herbs; low-fat protein.",
        "120 g chicken + 1 cup rice", 520, 38, 60, 12, 5, 2.5, 80,
        _t(["trimester_1","high_protein","low_sodium","vitamin_rich","general"]),
        _t([]), "non-veg", "general",
    ),

    # T2 – non-veg – general – gluten-free
    (
        "lunch", "Grilled Chicken with Quinoa & Steamed Veg",
        "Lean protein with low-GI quinoa and mixed vegetables.",
        "120 g chicken + 1 cup quinoa", 560, 42, 55, 14, 8, 4.0, 150,
        _t(["trimester_2","trimester_3","high_protein","low_gi","low_sodium","general"]),
        _t([]), "non-veg", "general",
    ),
    # T2 – veg – indian – dairy
    (
        "lunch", "Bajra Roti with Methi Sabzi & Curd",
        "Iron-rich bajra (pearl millet) with calcium-rich fenugreek and curd.",
        "2 roti + sabzi + curd", 520, 18, 70, 14, 9, 5.5, 320,
        _t(["trimester_2","trimester_3","high_iron","high_calcium","low_gi","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),
    # T2 – vegan – indian – allergy-free
    (
        "lunch", "Rajma Chawal (low-sodium)",
        "Kidney-bean curry with rice; iron, protein and fibre.",
        "1 katori rajma + 1 cup rice", 560, 22, 90, 8, 12, 5.8, 140,
        _t(["trimester_2","trimester_3","high_iron","high_protein","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T2 – vegan – general – soy
    (
        "lunch", "Tofu Stir-fry with Brown Rice",
        "Calcium- and protein-rich tofu, broccoli, capsicum stir-fry on brown rice.",
        "150 g tofu + 1 cup rice", 540, 28, 70, 14, 9, 5.0, 380,
        _t(["trimester_2","trimester_3","high_protein","high_calcium","high_iron","low_sodium","general"]),
        _t(["soy"]), "vegan", "general",
    ),
    # T2 – veg – general – dairy-free, gluten-free, nut-free
    (
        "lunch", "Chickpea & Spinach Masala with Rice",
        "Iron-packed chole with spinach; serves folate, iron and protein.",
        "1 katori chole + 1 cup rice", 540, 20, 84, 9, 13, 6.5, 180,
        _t(["trimester_2","high_iron","high_protein","vitamin_rich","indian"]),
        _t([]), "vegan", "indian",
    ),

    # T3 – non-veg – general – fish
    (
        "lunch", "Baked Salmon with Sweet Potato",
        "Omega-3 rich salmon for fetal brain development; vitamin-A sweet potato.",
        "120 g salmon + 1 sweet potato", 520, 36, 48, 18, 6, 1.5, 90,
        _t(["trimester_2","trimester_3","high_protein","vitamin_rich","low_sodium","general"]),
        _t(["fish"]), "non-veg", "general",
    ),
    # T3 – vegan – general – allergy-free
    (
        "lunch", "Chickpea & Spinach Stew with Roti",
        "Iron, fibre and plant protein — third-trimester friendly.",
        "1 katori + 1 roti", 470, 19, 65, 10, 12, 6.0, 200,
        _t(["trimester_2","trimester_3","high_iron","high_protein","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – veg – indian – dairy-free, gluten-free
    (
        "lunch", "Sambar Rice with Ghee",
        "High-protein sambar (lentil vegetable curry) over rice with a drizzle "
        "of ghee; provides iron, protein and calcium.",
        "1.5 cups sambar rice + ghee", 560, 20, 85, 12, 10, 5.5, 160,
        _t(["trimester_3","high_protein","high_iron","high_calorie","indian"]),
        _t([]), "veg", "indian",
    ),
    # T3 – veg – general – dairy (paneer)
    (
        "lunch", "Palak Paneer with Brown Rice",
        "Spinach and paneer curry — loaded with calcium, iron and protein "
        "for the final trimester.",
        "1 katori + 1 cup rice", 580, 28, 70, 20, 8, 6.5, 460,
        _t(["trimester_3","high_calcium","high_iron","high_protein","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),

    # =========================================================================
    # EVENING SNACK
    # =========================================================================

    # T1 – veg – indian – gluten
    (
        "evening_snack", "Vegetable Vermicelli Upma",
        "Light, savoury and carb-balanced.",
        "1 small bowl", 220, 7, 38, 5, 4, 2.0, 80,
        _t(["trimester_1","light","low_sodium","indian"]),
        _t(["gluten"]), "veg", "indian",
    ),
    # T1 – vegan – indian – allergy-free
    (
        "evening_snack", "Boiled Sweet Potato Chaat",
        "Naturally sweet, low-GI and rich in vitamin A.",
        "1 medium", 200, 4, 44, 1, 6, 1.5, 60,
        _t(["trimester_1","low_gi","vitamin_rich","light","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T1 – vegan – general – allergy-free
    (
        "evening_snack", "Fresh Vegetable Sticks with Guacamole",
        "Crunchy carrot, cucumber and celery with avocado dip; "
        "folate-rich for first trimester.",
        "veg sticks + 3 tbsp guacamole", 170, 4, 18, 9, 6, 1.5, 40,
        _t(["trimester_1","light","vitamin_rich","low_gi","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),
    # T1 – veg – general – dairy
    (
        "evening_snack", "Warm Milk with Cardamom & Honey",
        "Calcium boost with calming cardamom; helps with first-trimester fatigue.",
        "1 cup", 160, 7, 22, 4, 0, 0.5, 300,
        _t(["trimester_1","high_calcium","light","general"]),
        _t(["dairy"]), "veg", "general",
    ),

    # T2 – vegan – indian – allergy-free
    (
        "evening_snack", "Sweet-corn Bhel (low-spice)",
        "Crunchy mix with sprouts, corn and tomato.",
        "1 small bowl", 250, 8, 42, 5, 6, 2.5, 70,
        _t(["trimester_2","light","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T2 – veg – general – dairy, nuts
    (
        "evening_snack", "Greek Yogurt with Berries & Walnuts",
        "Calcium, protein and antioxidant-packed.",
        "1 cup", 280, 16, 24, 12, 4, 1.5, 280,
        _t(["trimester_2","trimester_3","high_calcium","high_protein","vitamin_rich","general"]),
        _t(["dairy","nuts"]), "veg", "general",
    ),
    # T2 – veg – general – dairy-free, nut-free, gluten-free
    (
        "evening_snack", "Edamame with Sea Salt",
        "Plant protein powerhouse; high in folate and calcium.",
        "1 cup edamame", 190, 17, 14, 8, 8, 3.0, 100,
        _t(["trimester_2","high_protein","high_iron","low_gi","general"]),
        _t(["soy"]), "vegan", "general",
    ),
    # T2 – vegan – general – allergy-free
    (
        "evening_snack", "Pumpkin Seeds & Dried Cranberry Trail Mix",
        "Iron, zinc and magnesium from pumpkin seeds; antioxidants from cranberry.",
        "2 tbsp each", 200, 7, 22, 10, 3, 3.0, 50,
        _t(["trimester_2","high_iron","vitamin_rich","general"]),
        _t([]), "vegan", "general",
    ),

    # T3 – veg – general – dairy-free, gluten-free
    (
        "evening_snack", "Hummus with Carrot & Cucumber Sticks",
        "Protein, fibre and crunch — keeps blood sugar steady.",
        "3 tbsp hummus + veg sticks", 180, 7, 18, 9, 5, 2.0, 60,
        _t(["trimester_3","low_gi","high_protein","light","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – vegan – indian – allergy-free
    (
        "evening_snack", "Roasted Chana (Chickpeas)",
        "Iron-rich, protein-rich crunchy snack.",
        "1 handful", 180, 9, 26, 3, 6, 4.0, 60,
        _t(["trimester_2","trimester_3","high_iron","high_protein","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T3 – veg – general – dairy, nut-free
    (
        "evening_snack", "Cheese & Whole-grain Crackers",
        "Calcium-rich cheese with high-fibre crackers; quick energy for third trimester.",
        "2 crackers + 40 g cheese", 260, 12, 26, 12, 3, 0.5, 320,
        _t(["trimester_3","high_calcium","high_calorie","general"]),
        _t(["dairy","gluten"]), "veg", "general",
    ),
    # T3 – non-veg – general – egg
    (
        "evening_snack", "Mini Egg & Vegetable Frittata",
        "Protein and choline-rich small frittata with spinach and tomato.",
        "1 small frittata", 190, 14, 8, 12, 2, 2.0, 90,
        _t(["trimester_3","high_protein","vitamin_rich","low_gi","general"]),
        _t(["eggs","dairy"]), "non-veg", "general",
    ),

    # =========================================================================
    # DINNER
    # =========================================================================

    # T1 – veg – indian – light
    (
        "dinner", "Moong Dal Chilla with Mint Chutney",
        "High-protein, light dinner — easy on digestion.",
        "2 chilla", 360, 18, 42, 9, 7, 4.0, 100,
        _t(["trimester_1","light","high_protein","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),
    # T1 – veg – general – light, gluten-free
    (
        "dinner", "Vegetable Soup with Whole-grain Bread",
        "Hydrating, low-calorie option when appetite is low.",
        "1 large bowl + 2 slices", 280, 10, 42, 6, 7, 2.5, 120,
        _t(["trimester_1","light","low_calorie","low_sodium","general"]),
        _t(["gluten"]), "veg", "general",
    ),
    # T1 – non-veg – general – light
    (
        "dinner", "Lemon-Coriander Chicken Soup",
        "Light, immunity-boosting and high-protein.",
        "1 large bowl", 260, 24, 12, 9, 2, 1.5, 60,
        _t(["trimester_1","light","high_protein","low_sodium","vitamin_rich","general"]),
        _t([]), "non-veg", "general",
    ),
    # T1 – vegan – indian – allergy-free
    (
        "dinner", "Vegetable Daliya (Broken Wheat Porridge)",
        "Easy-to-digest broken wheat with vegetables; fibre-rich and comforting.",
        "1 large bowl", 360, 12, 62, 7, 9, 3.5, 80,
        _t(["trimester_1","light","low_sodium","vitamin_rich","indian"]),
        _t(["gluten"]), "vegan", "indian",
    ),
    # T1 – veg – general – dairy-free, gluten-free
    (
        "dinner", "Rice & Mung Bean Congee",
        "Warm, easily digestible rice porridge with green mung beans. "
        "Soothing for first-trimester nausea.",
        "1 large bowl", 380, 14, 68, 5, 8, 4.0, 90,
        _t(["trimester_1","light","low_sodium","high_protein","general"]),
        _t([]), "vegan", "general",
    ),

    # T2 – veg – indian – dairy, gluten
    (
        "dinner", "Multigrain Roti with Mixed Veg Curry & Curd",
        "Balanced dinner with whole grains, vegetables and probiotic curd.",
        "2 roti + 1 cup sabzi + curd", 480, 17, 70, 12, 10, 4.5, 280,
        _t(["trimester_2","high_calcium","low_sodium","light","indian"]),
        _t(["dairy","gluten"]), "veg", "indian",
    ),
    # T2 – non-veg – general – fish
    (
        "dinner", "Grilled Fish Curry with Steamed Rice",
        "Omega-3 lean protein with low-fat curry.",
        "120 g fish + 1 cup rice", 520, 32, 60, 12, 5, 2.5, 110,
        _t(["trimester_2","trimester_3","high_protein","vitamin_rich","low_sodium","general"]),
        _t(["fish"]), "non-veg", "general",
    ),
    # T2 – veg – indian – dairy
    (
        "dinner", "Paneer Bhurji with Rotis",
        "High-calcium and high-protein dinner.",
        "1 cup paneer + 2 roti", 540, 26, 55, 22, 6, 3.5, 480,
        _t(["trimester_2","trimester_3","high_calcium","high_protein","indian"]),
        _t(["dairy","gluten"]), "veg", "indian",
    ),
    # T2 – vegan – general – allergy-free
    (
        "dinner", "Black Bean & Corn Burrito Bowl",
        "Iron- and protein-rich black beans with sweet corn, brown rice and avocado. "
        "No common allergens.",
        "1 bowl", 530, 20, 78, 14, 14, 5.5, 120,
        _t(["trimester_2","high_iron","high_protein","vitamin_rich","general"]),
        _t([]), "vegan", "general",
    ),
    # T2 – vegan – indian – allergy-free (low-gi)
    (
        "dinner", "Lauki Dal with Jowar Roti",
        "Bottle gourd and chana dal curry with sorghum roti; low-GI and high-iron.",
        "1 katori dal + 2 roti", 460, 18, 65, 9, 10, 5.0, 140,
        _t(["trimester_2","low_gi","high_iron","low_sodium","indian"]),
        _t([]), "vegan", "indian",
    ),

    # T3 – vegan – general – allergy-free
    (
        "dinner", "Chickpea & Spinach Stew",
        "Iron, fibre and plant protein — third-trimester friendly.",
        "1 katori + 1 roti", 470, 19, 65, 10, 12, 6.0, 200,
        _t(["trimester_2","trimester_3","high_iron","high_protein","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – veg – indian – dairy, gluten-free
    (
        "dinner", "Curd Rice with Pomegranate & Curry Leaves",
        "Probiotic-rich curd rice with pomegranate for iron and vitamin C; "
        "cooling and easy to digest.",
        "1.5 cups", 420, 14, 68, 10, 4, 1.5, 320,
        _t(["trimester_3","high_calcium","light","low_sodium","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),
    # T3 – non-veg – general – egg
    (
        "dinner", "Baked Egg & Vegetable Casserole",
        "Protein-dense casserole with eggs, spinach, capsicum and tomato. "
        "Choline-rich for fetal brain development.",
        "1 portion", 400, 24, 28, 20, 5, 3.5, 140,
        _t(["trimester_3","high_protein","vitamin_rich","low_sodium","general"]),
        _t(["eggs"]), "non-veg", "general",
    ),
    # T3 – veg – general – dairy-free, gluten-free, nut-free
    (
        "dinner", "Sweet Potato & Lentil Dal",
        "Vitamin-A sweet potato with orange lentils; high-calorie, iron-rich "
        "and comforting in third trimester.",
        "1 large bowl", 490, 20, 75, 9, 12, 6.5, 150,
        _t(["trimester_3","high_iron","high_calorie","vitamin_rich","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),

    # =========================================================================
    # BEDTIME
    # =========================================================================

    # T1 – vegan – general – nuts
    (
        "bedtime", "Warm Almond Milk with Turmeric",
        "Calcium-rich golden milk; eases sleep, supports bone health.",
        "1 cup", 140, 5, 14, 6, 1, 1.0, 320,
        _t(["trimester_1","trimester_2","trimester_3","high_calcium","light","general"]),
        _t(["nuts"]), "vegan", "general",
    ),
    # T1 – vegan – general – allergy-free (nut-free alternative)
    (
        "bedtime", "Warm Oat Milk with Cinnamon",
        "Creamy oat milk with cinnamon; dairy-free calcium source for "
        "those with dairy/nut allergies.",
        "1 cup", 130, 3, 22, 3, 2, 1.0, 280,
        _t(["trimester_1","trimester_2","high_calcium","light","general"]),
        _t(["gluten"]), "vegan", "general",
    ),
    # T1 – vegan – general – allergy-free
    (
        "bedtime", "Chamomile Tea with Oat Crackers",
        "Caffeine-free, gentle on the stomach.",
        "1 cup + 2 crackers", 120, 3, 20, 3, 2, 0.8, 30,
        _t(["trimester_1","light","low_calorie","low_sodium","general"]),
        _t(["gluten"]), "vegan", "general",
    ),
    # T1 – vegan – general – allergy-free, gluten-free, nut-free
    (
        "bedtime", "Warm Ragi Porridge with Jaggery",
        "Finger-millet porridge sweetened with jaggery. High in calcium and "
        "iron — ideal for all trimesters.",
        "1 small cup", 160, 4, 28, 3, 2, 2.5, 210,
        _t(["trimester_1","trimester_2","trimester_3","high_calcium","high_iron","light","indian"]),
        _t([]), "vegan", "indian",
    ),

    # T2 – veg – indian – dairy
    (
        "bedtime", "Warm Milk with Saffron & Cardamom",
        "Traditional calcium-rich bedtime drink.",
        "1 cup", 180, 8, 18, 8, 0, 0.5, 320,
        _t(["trimester_3","high_calcium","light","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),
    # T2 – vegan – general – nuts
    (
        "bedtime", "Soaked Almonds & Dates (5 + 2)",
        "Iron, calcium and healthy fats for overnight nourishment.",
        "5 almonds + 2 dates", 160, 4, 22, 8, 3, 1.8, 110,
        _t(["trimester_2","trimester_3","high_iron","high_calcium","high_calorie","general"]),
        _t(["nuts"]), "vegan", "general",
    ),
    # T2 – vegan – general – nuts
    (
        "bedtime", "Banana with Peanut Butter",
        "Magnesium- and potassium-rich, supports muscle relaxation.",
        "1 banana + 1 tbsp PB", 230, 6, 32, 10, 4, 0.7, 30,
        _t(["trimester_2","trimester_3","light","high_calorie","vitamin_rich","general"]),
        _t(["nuts"]), "vegan", "general",
    ),
    # T2 – vegan – general – allergy-free
    (
        "bedtime", "Banana & Date Smoothie",
        "Naturally sweet banana blended with 2 dates and water; no allergens, "
        "calming and iron-rich.",
        "1 glass", 200, 3, 44, 1, 4, 1.5, 40,
        _t(["trimester_2","trimester_3","light","high_iron","vitamin_rich","general"]),
        _t([]), "vegan", "general",
    ),

    # T3 – veg – indian – dairy
    (
        "bedtime", "Warm Milk with Ashwagandha",
        "Calcium-rich milk with a pinch of ashwagandha for sleep and stress relief.",
        "1 cup", 180, 8, 18, 8, 0, 0.3, 320,
        _t(["trimester_3","high_calcium","light","indian"]),
        _t(["dairy"]), "veg", "indian",
    ),
    # T3 – vegan – general – allergy-free
    (
        "bedtime", "Warm Chickpea Milk with Cinnamon",
        "Dairy-free calcium and protein drink made from soaked chickpeas. "
        "Safe for dairy, nut and soy allergies.",
        "1 cup", 150, 6, 20, 4, 3, 2.0, 180,
        _t(["trimester_3","high_calcium","high_protein","light","general"]),
        _t([]), "vegan", "general",
    ),
    # T3 – vegan – general – allergy-free, gluten-free, nut-free
    (
        "bedtime", "Rice Milk with Turmeric & Ginger",
        "Anti-inflammatory, dairy-free bedtime drink. Gentle for mothers "
        "with multiple allergies.",
        "1 cup", 120, 1, 24, 2, 0, 0.5, 100,
        _t(["trimester_3","light","low_sodium","general"]),
        _t([]), "vegan", "general",
    ),
]
# fmt: on


def seed_meal_templates(db: Session) -> int:
    """Insert any missing curated meals and refresh tags on existing ones.

    Returns the number of newly inserted rows.
    """
    added = 0
    for entry in _TEMPLATES:
        (slot, name, description, portion, kcal, protein, carbs, fat, fiber,
         iron, calcium, tags, allergens, diet_type, cuisine) = entry
        existing = (
            db.query(MealTemplate)
            .filter(MealTemplate.slot == slot, MealTemplate.name == name)
            .first()
        )
        if existing is not None:
            # Refresh tags so trimester/allergy corrections propagate.
            existing.tags = tags
            existing.allergens = allergens
            continue
        db.add(MealTemplate(
            slot=slot,
            name=name,
            description=description,
            portion=portion,
            calories=kcal,
            protein_g=protein,
            carbs_g=carbs,
            fat_g=fat,
            fiber_g=fiber,
            iron_mg=iron,
            calcium_mg=calcium,
            tags=tags,
            allergens=allergens,
            diet_type=diet_type,
            cuisine=cuisine,
            is_active=True,
        ))
        added += 1
    if added:
        log.info("Seeded %d meal templates", added)
    db.commit()
    return added
