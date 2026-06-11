"""
Curated seed library for the Pregnancy Learning Center.

Idempotent: rows with the same title (article), question (FAQ) or tip_text
(daily tip) are not duplicated.

All copy is generic, medically conservative and references publicly available
maternal-health guideline conventions (WHO / NHS / CDC). Nothing here is
intended as a substitute for clinical advice; the doctor-approval flag is
used so authoring doctors can replace or enhance any item.
"""
from __future__ import annotations

import json
import logging

from sqlalchemy.orm import Session

from .models import Article, DailyTip, Faq

log = logging.getLogger(__name__)


def _j(values: list) -> str:
    return json.dumps(values)


# ---------------------------------------------------------------------------
# Articles
# ---------------------------------------------------------------------------

_ARTICLES: list[dict] = [
    # --- First trimester ---
    {
        "title": "What Happens During Weeks 1–12 of Pregnancy",
        "summary": "An overview of how your body changes during the first trimester and what to expect week by week.",
        "category": "trimester",
        "trimester": 1,
        "week_min": 1, "week_max": 13,
        "condition_tags": [],
        "tags": ["first_trimester", "overview", "what_to_expect"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "Adapted from public maternal-health guidance (WHO/NHS).",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Your body produces extra hormones to support pregnancy.",
            "Common symptoms include nausea, fatigue and breast tenderness.",
            "Most major organs of your baby form during this period.",
        ],
        "body_markdown": (
            "## A quick map of the first 12 weeks\n\n"
            "The first trimester is when your body changes the most while looking the same on the outside.\n\n"
            "### Weeks 1–4\n"
            "The fertilised egg implants in the uterus. You may not notice anything yet.\n\n"
            "### Weeks 5–8\n"
            "Hormone levels rise sharply. Most mothers feel nausea, fatigue and food aversions in this window.\n\n"
            "### Weeks 9–12\n"
            "The baby's heartbeat is detectable. Major organs begin to form. Energy may start returning.\n\n"
            "> If you notice heavy bleeding, severe cramping or fainting, contact your doctor immediately."
        ),
    },
    {
        "title": "Managing Morning Sickness Naturally",
        "summary": "Practical, gentle ways to ease nausea without medication, and when nausea becomes a warning sign.",
        "category": "nutrition",
        "trimester": 1,
        "week_min": 4, "week_max": 16,
        "condition_tags": ["morning_sickness"],
        "tags": ["nausea", "morning_sickness", "first_trimester"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Eat small meals every 2–3 hours.",
            "Ginger, lemon and cool plain foods often help.",
            "Persistent vomiting (more than 4 times/day) needs medical attention.",
        ],
        "body_markdown": (
            "## You're not alone — 7 in 10 mothers feel nauseous\n\n"
            "### What usually helps\n"
            "- Sip warm water with a slice of ginger or lemon first thing in the morning.\n"
            "- Keep a few dry crackers or roasted chickpeas on your bedside table.\n"
            "- Avoid spicy, oily or strongly perfumed foods.\n"
            "- Eat little and often — never on an empty stomach.\n\n"
            "### When to call your doctor\n"
            "Nausea that prevents you from drinking water, weight loss, or vomiting blood are signs of "
            "hyperemesis gravidarum. Please contact your doctor the same day."
        ),
    },
    {
        "title": "Why Folic Acid Matters in Early Pregnancy",
        "summary": "Folic acid prevents neural tube defects. Here's how much, when, and from which foods.",
        "category": "nutrition",
        "trimester": 1,
        "week_min": 1, "week_max": 13,
        "condition_tags": [],
        "tags": ["folic_acid", "nutrition", "first_trimester"],
        "reading_time_min": 3,
        "source": "curated",
        "source_attribution": "Public guideline summary (WHO maternal nutrition).",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "400–600 mcg daily, ideally from before conception.",
            "Leafy greens, lentils, citrus and fortified grains are top sources.",
            "Don't double-dose — discuss your supplement with your doctor.",
        ],
        "body_markdown": (
            "Folic acid (vitamin B9) helps form your baby's brain and spinal cord. The first 28 days are critical, "
            "so most maternal-health programs recommend starting supplementation before conception.\n\n"
            "### Best food sources\n"
            "- Cooked spinach, methi, amaranth and other dark leafy greens\n"
            "- Lentils, kidney beans, chickpeas\n"
            "- Oranges, papaya, banana\n"
            "- Fortified cereals or atta\n\n"
            "Combine these with vitamin-C foods (lemon, citrus, tomato) to improve absorption."
        ),
    },
    # --- Second trimester ---
    {
        "title": "Your Baby's Development in the Second Trimester",
        "summary": "Weeks 13–27: rapid growth, kicks begin, and what to watch for.",
        "category": "baby_dev",
        "trimester": 2,
        "week_min": 13, "week_max": 27,
        "condition_tags": [],
        "tags": ["baby_development", "second_trimester"],
        "reading_time_min": 5,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Your baby starts to hear sounds around week 18.",
            "First kicks are usually felt between 18 and 22 weeks.",
            "An anomaly scan is typically done around 20 weeks.",
        ],
        "body_markdown": (
            "The second trimester is often the most comfortable. Nausea fades, energy returns and the bump becomes visible.\n\n"
            "### Key milestones\n"
            "- **Week 14:** Baby can make facial expressions.\n"
            "- **Week 18:** Hearing develops — your voice now travels through.\n"
            "- **Week 20:** Detailed anomaly scan.\n"
            "- **Week 24:** Baby reaches the age of viability.\n\n"
            "Talk to your baby — many mothers find it deeply calming."
        ),
    },
    {
        "title": "Healthy Weight Gain Across Pregnancy",
        "summary": "How much weight gain is healthy by trimester, and what to do if you're outside the range.",
        "category": "nutrition",
        "trimester": 2,
        "week_min": 12, "week_max": 40,
        "condition_tags": ["obesity", "underweight"],
        "tags": ["weight_gain", "nutrition"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Average healthy gain: 10–14 kg over 9 months.",
            "Most gain happens in trimesters 2 and 3.",
            "Sudden gain (>2 kg/week) can be a warning of pre-eclampsia.",
        ],
        "body_markdown": (
            "Healthy weight gain depends on your starting BMI. Speak with your doctor for a personalised range.\n\n"
            "### Rough guide\n"
            "| Starting BMI | Total gain |\n"
            "|---|---|\n"
            "| Below 18.5 | 12–18 kg |\n"
            "| 18.5–24.9 | 11–16 kg |\n"
            "| 25–29.9 | 7–11 kg |\n"
            "| 30+ | 5–9 kg |\n\n"
            "Sudden weight gain combined with swelling and headache may signal pre-eclampsia. "
            "Contact your doctor the same day if you notice this combination."
        ),
    },
    {
        "title": "Safe Exercises for the Second Trimester",
        "summary": "Gentle exercises that strengthen your body for labour and improve mood.",
        "category": "exercise",
        "trimester": 2,
        "week_min": 13, "week_max": 27,
        "condition_tags": [],
        "tags": ["exercise", "yoga", "walking", "second_trimester"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Aim for 30 minutes of moderate activity most days.",
            "Walking, prenatal yoga and swimming are safest.",
            "Stop and rest if you feel breathless, dizzy or have any bleeding.",
        ],
        "body_markdown": (
            "### Recommended\n"
            "- 20–30 min of brisk walking 5 days a week\n"
            "- Prenatal yoga (skip deep twists and backbends)\n"
            "- Swimming and water aerobics\n"
            "- Pelvic floor (Kegel) exercises\n\n"
            "### Avoid\n"
            "- Contact sports, horse riding, skiing\n"
            "- Exercises lying flat on your back after week 16\n"
            "- Holding your breath under exertion"
        ),
    },
    # --- Third trimester ---
    {
        "title": "Signs Labour May Be Near",
        "summary": "Real labour vs Braxton-Hicks: how to tell, and what to pack in your hospital bag.",
        "category": "trimester",
        "trimester": 3,
        "week_min": 32, "week_max": 42,
        "condition_tags": [],
        "tags": ["labour", "third_trimester", "delivery"],
        "reading_time_min": 5,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Real contractions get stronger and more regular over time.",
            "A 'show' (mucus plug) or water breaking is a labour sign.",
            "Call your doctor when contractions are 5 minutes apart for 1 hour.",
        ],
        "body_markdown": (
            "### Early signs\n"
            "- A heavy feeling in the lower belly\n"
            "- Mild backache\n"
            "- A pink/brown mucus discharge (the 'show')\n\n"
            "### Active labour\n"
            "Contractions become regular, more painful and stay strong even when you move.\n\n"
            "**Call your doctor immediately if**:\n"
            "- Your waters break\n"
            "- You bleed bright red\n"
            "- The baby's movements suddenly decrease"
        ),
    },
    {
        "title": "Hospital Bag Checklist for Delivery",
        "summary": "A practical packing list for mother, partner and baby.",
        "category": "trimester",
        "trimester": 3,
        "week_min": 32, "week_max": 42,
        "condition_tags": [],
        "tags": ["hospital_bag", "delivery", "checklist"],
        "reading_time_min": 3,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Pack at least 2 weeks before your due date.",
            "Carry hospital paperwork, IDs and insurance details.",
            "Include essentials for the baby's first 48 hours.",
        ],
        "body_markdown": (
            "### For you\n"
            "- 2–3 comfortable nightgowns\n"
            "- Toiletries, hair tie, lip balm\n"
            "- Slip-on slippers, warm socks\n"
            "- Nursing bras and breast pads\n"
            "- Going-home outfit (loose)\n\n"
            "### For baby\n"
            "- 4–5 onesies, mittens, caps, socks\n"
            "- Receiving blanket\n"
            "- Newborn nappies\n"
            "- A car seat for the ride home\n\n"
            "### Paperwork\n"
            "- Hospital ID, insurance, doctor's letter\n"
            "- Birth plan (if any)"
        ),
    },
    # --- Emergency awareness ---
    {
        "title": "Pregnancy Warning Signs You Should Never Ignore",
        "summary": "These symptoms mean you should call your doctor or go to the hospital immediately.",
        "category": "emergency",
        "trimester": None,
        "week_min": 1, "week_max": 42,
        "condition_tags": [],
        "tags": ["emergency", "warning_signs", "danger"],
        "reading_time_min": 4,
        "source": "curated",
        "source_attribution": "Adapted from public maternal-emergency guidance.",
        "severity": "emergency",
        "doctor_approved": True,
        "key_takeaways": [
            "Heavy bleeding is never normal in pregnancy.",
            "Severe headache + blurred vision can signal pre-eclampsia.",
            "Reduced fetal movement after week 24 needs same-day review.",
        ],
        "body_markdown": (
            "## Call your doctor immediately if you have any of these\n\n"
            "- **Bleeding** that soaks a pad in an hour, with or without pain\n"
            "- **Severe headache** that does not respond to rest\n"
            "- **Blurred vision** or flashing lights\n"
            "- **Severe swelling** of the face, hands or feet appearing suddenly\n"
            "- **Continuous abdominal pain**\n"
            "- **Fever** above 38.5°C / 101°F\n"
            "- **Less than 10 baby movements** in 2 hours (after 28 weeks)\n"
            "- **Watery discharge** (your waters breaking) before 37 weeks\n"
            "- **Burning pain when passing urine** with fever\n\n"
            "Trust your instincts. If something feels wrong, get checked."
        ),
    },
    {
        "title": "Counting Baby Kicks — A Simple Daily Habit",
        "summary": "Why kick counts matter from week 28 and how to do them at home.",
        "category": "emergency",
        "trimester": 3,
        "week_min": 28, "week_max": 42,
        "condition_tags": [],
        "tags": ["kick_count", "fetal_movement", "third_trimester"],
        "reading_time_min": 3,
        "source": "curated",
        "severity": "warning",
        "doctor_approved": True,
        "key_takeaways": [
            "From week 28, count fetal movements once a day.",
            "10 movements within 2 hours is usually reassuring.",
            "A sudden, lasting drop in movements needs same-day medical review.",
        ],
        "body_markdown": (
            "After week 28, fetal movements become a key wellbeing signal.\n\n"
            "### How to count\n"
            "1. Pick a time when your baby is usually active (after a meal).\n"
            "2. Lie on your left side and relax.\n"
            "3. Note how long it takes to feel 10 distinct movements.\n\n"
            "Less than 10 in 2 hours, or a clear drop from the baby's usual pattern, is a warning sign.\n"
            "Drink something cold, lie down again and recount. If still reduced, **call your doctor immediately**."
        ),
    },
    # --- Mental wellness ---
    {
        "title": "Managing Anxiety During Pregnancy",
        "summary": "Why anxiety rises in pregnancy and small daily practices that genuinely help.",
        "category": "mental_health",
        "trimester": None,
        "week_min": 1, "week_max": 42,
        "condition_tags": [],
        "tags": ["mental_health", "anxiety", "wellbeing"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Anxiety in pregnancy is common and very treatable.",
            "Sleep, sunlight, gentle movement and talking openly all help.",
            "Persistent low mood for more than 2 weeks deserves professional support.",
        ],
        "body_markdown": (
            "Hormone changes, body changes and the unknown can all raise anxiety. You are not alone.\n\n"
            "### Daily practices that help\n"
            "- 10 minutes of slow breathing (4-second inhale, 6-second exhale)\n"
            "- A 20-minute outdoor walk in daylight\n"
            "- A short evening journal\n"
            "- Talking to your partner or a trusted friend\n\n"
            "If your mood stays low for more than 2 weeks, you lose interest in things you usually enjoy, "
            "or you have thoughts of self-harm, **please reach out to your doctor**. Antenatal depression is "
            "treatable and seeking help is a strength."
        ),
    },
    # --- Condition-specific ---
    {
        "title": "Iron-Rich Foods for Anemic Mothers",
        "summary": "A simple plate of iron-rich, easy-to-source foods to help raise your haemoglobin.",
        "category": "nutrition",
        "trimester": None,
        "week_min": 1, "week_max": 42,
        "condition_tags": ["anemia"],
        "tags": ["anemia", "iron", "nutrition"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "warning",
        "doctor_approved": True,
        "key_takeaways": [
            "Pair iron-rich foods with vitamin C (lemon, amla, citrus) for absorption.",
            "Avoid tea and coffee within 1 hour of iron-rich meals.",
            "Take iron tablets exactly as prescribed.",
        ],
        "body_markdown": (
            "### Top iron-rich foods\n"
            "- Cooked spinach, methi, drumstick leaves\n"
            "- Beetroot, dates, pomegranate, raisins\n"
            "- Ragi (finger millet), bajra (pearl millet)\n"
            "- Lentils (dal), kidney beans, chickpeas\n"
            "- Jaggery, sesame seeds\n\n"
            "### Better absorption\n"
            "- Add a squeeze of lemon, amla or tomato to dal and sabzi\n"
            "- Cook in a clean iron kadhai when possible\n"
            "- Don't drink tea or coffee within an hour of iron-rich meals"
        ),
    },
    {
        "title": "Eating Well with Gestational Diabetes",
        "summary": "Low-GI choices, portion balance and simple swaps for stable blood sugar.",
        "category": "nutrition",
        "trimester": None,
        "week_min": 20, "week_max": 42,
        "condition_tags": ["gestational_diabetes"],
        "tags": ["gestational_diabetes", "low_gi", "diabetes"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "warning",
        "doctor_approved": True,
        "key_takeaways": [
            "Choose low-GI carbs: whole grains, dal, oats over white rice/bread.",
            "Pair carbs with protein and healthy fats.",
            "Test sugar as advised and walk for 10 minutes after meals.",
        ],
        "body_markdown": (
            "### Helpful swaps\n"
            "- White rice → brown rice, hand-pounded rice, millets\n"
            "- White bread → multigrain or sprouted-grain bread\n"
            "- Sweet juice → whole fruit (apple, pear, berries)\n"
            "- Sugar tea → unsweetened spiced milk\n\n"
            "### Plate idea\n"
            "Half plate non-starchy vegetables, quarter plate dal/paneer/egg/lean meat, quarter plate whole grain.\n\n"
            "A 10-minute walk after meals helps lower post-meal sugar."
        ),
    },
    {
        "title": "Sleeping Positions That Actually Help",
        "summary": "Why side-lying matters in trimesters 2 and 3, and quick tricks for better sleep.",
        "category": "exercise",
        "trimester": 2,
        "week_min": 16, "week_max": 42,
        "condition_tags": [],
        "tags": ["sleep", "left_side", "wellness"],
        "reading_time_min": 3,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Sleep on your left side after week 20 for better blood flow.",
            "Use a pillow between your knees and behind your back.",
            "Avoid lying flat on your back for long periods.",
        ],
        "body_markdown": (
            "After about week 20, the uterus is heavy enough that lying flat on the back can press on a major vein "
            "(the inferior vena cava), reducing blood flow to the baby.\n\n"
            "### Try this set-up\n"
            "- Lie on your **left** side.\n"
            "- Pillow between the knees to align your hips.\n"
            "- Folded pillow at the small of the back to stop you rolling.\n"
            "- A thin pillow under the bump for extra support.\n\n"
            "If you wake on your back, just roll back to the left and continue sleeping."
        ),
    },
    # --- Postpartum & newborn (WHO / CDC / PAHO-aligned) ---
    {
        "title": "Breastfeeding Basics: The First 48 Hours",
        "summary": "Skin-to-skin, early feeds, latch tips, and when to ask for lactation support.",
        "category": "baby_dev",
        "trimester": None,
        "week_min": 37,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["breastfeeding", "newborn", "postpartum", "lactation"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "Adapted from WHO/UNICEF breastfeeding guidance and PAHO maternal-newborn care modules.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Skin-to-skin within the first hour helps milk supply and bonding.",
            "Feed on demand — 8–12 times in 24 hours is normal for newborns.",
            "Painful cracks, fever, or a very sleepy baby need same-day review.",
        ],
        "body_markdown": (
            "## Starting strong\n\n"
            "Most babies are ready to feed within the first hour after birth. Skin-to-skin contact on your chest "
            "keeps them warm and triggers feeding instincts.\n\n"
            "### A good latch usually means\n"
            "- Baby's mouth covers most of the areola, not just the nipple\n"
            "- Chin touches the breast, nose slightly free\n"
            "- You hear swallowing, not clicking or pinching pain\n\n"
            "### First days are learning days\n"
            "Colostrum (the first milk) is small in amount but rich in antibodies. Frequent feeds tell your body "
            "to build supply over the next week.\n\n"
            "**Ask for help if:** nipples crack or bleed, baby has fewer than 6 wet nappies per day after day 4, "
            "or you develop fever with breast pain."
        ),
    },
    {
        "title": "Vaccines Recommended During Pregnancy",
        "summary": "Which vaccines protect you and your baby — flu, Tdap, COVID-19, and RSV — and when to get them.",
        "category": "trimester",
        "trimester": None,
        "week_min": 1,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["vaccines", "immunization", "flu", "tdap", "rsv"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "Summary of CDC ACIP pregnancy vaccination guidance (2024–2025).",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Influenza and Tdap are routinely recommended in pregnancy in most countries.",
            "Tdap in the third trimester helps protect your newborn from whooping cough.",
            "Discuss COVID-19 and RSV vaccines with your doctor based on season and local guidance.",
        ],
        "body_markdown": (
            "Vaccines in pregnancy protect **you** and give your baby antibodies in the first vulnerable months.\n\n"
            "### Commonly recommended\n"
            "- **Influenza (flu):** any trimester during flu season\n"
            "- **Tdap (whooping cough):** usually between weeks 27–36 of each pregnancy\n"
            "- **COVID-19:** follow your local health authority's current advice\n"
            "- **RSV:** in some regions, a single dose between weeks 32–36 during RSV season\n\n"
            "### What to bring to your appointment\n"
            "Your vaccination card, any allergies, and a list of vaccines you had in prior pregnancies.\n\n"
            "Never skip routine antenatal visits because of vaccine questions — your doctor can personalise the schedule."
        ),
    },
    {
        "title": "Postpartum Recovery: What Is Normal in the First 6 Weeks",
        "summary": "Bleeding, cramps, mood changes, and physical recovery after birth — plus red-flag symptoms.",
        "category": "trimester",
        "trimester": None,
        "week_min": 37,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["postpartum", "recovery", "lochia", "after_birth"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "Adapted from WHO postnatal care guidance.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Bleeding (lochia) gradually lightens over 4–6 weeks.",
            "Mild after-pains with breastfeeding are common.",
            "Heavy bleeding, fever, or foul-smelling discharge needs urgent care.",
        ],
        "body_markdown": (
            "Your body needs time to heal after birth — whether vaginal or caesarean.\n\n"
            "### Week 1\n"
            "Bleeding is heaviest; rest as much as possible. Accept help with meals and housework.\n\n"
            "### Weeks 2–4\n"
            "Bleeding turns pink/brown. Uterine cramps ('after-pains') can occur during feeds.\n\n"
            "### Weeks 4–6\n"
            "Most mothers feel more energetic. Pelvic floor exercises can restart when comfortable.\n\n"
            "**Call your doctor urgently if you soak more than one pad per hour, pass large clots, have fever above 38°C, "
            "or notice worsening belly pain or foul discharge.**"
        ),
    },
    {
        "title": "Baby Blues vs Postpartum Depression",
        "summary": "How to tell normal mood swings apart from depression that needs treatment.",
        "category": "mental_health",
        "trimester": None,
        "week_min": 37,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["postpartum", "depression", "mental_health", "EPDS"],
        "reading_time_min": 4,
        "source": "curated",
        "source_attribution": "Aligned with WHO maternal mental health guidance and EPDS screening practice.",
        "severity": "warning",
        "doctor_approved": True,
        "key_takeaways": [
            "Baby blues peak around days 3–5 and usually ease within 2 weeks.",
            "Depression lasting more than 2 weeks, or thoughts of self-harm, need professional help.",
            "Treatment works — reaching out early protects you and your baby.",
        ],
        "body_markdown": (
            "### Baby blues (very common)\n"
            "Tearfulness, irritability and overwhelm in the first 2 weeks, often when milk 'comes in'. "
            "Symptoms come and go and improve with rest and support.\n\n"
            "### Postpartum depression (needs care)\n"
            "Low mood most of the day, loss of interest, guilt, poor sleep even when baby sleeps, "
            "or difficulty bonding for **more than 2 weeks**.\n\n"
            "Use the **Postpartum Hub → depression screening (EPDS)** in LifeNest, and share results with your doctor. "
            "If you have thoughts of harming yourself or your baby, contact emergency services or your doctor **today**."
        ),
    },
    {
        "title": "Newborn Care in the First Week at Home",
        "summary": "Nappies, umbilical cord care, bathing, temperature, and when to call the doctor.",
        "category": "baby_dev",
        "trimester": None,
        "week_min": 37,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["newborn", "baby_care", "postpartum"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "Adapted from WHO newborn care recommendations.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Expect 6+ wet nappies per day once milk supply is established.",
            "Keep the cord stump clean and dry; fold nappies below it.",
            "Jaundice, poor feeding, or fever in a newborn needs same-day review.",
        ],
        "body_markdown": (
            "### Daily checks\n"
            "- **Feeding:** 8–12 feeds per 24 hours\n"
            "- **Wet nappies:** at least 6 per day after day 4–5\n"
            "- **Stools:** yellow/seedy if breastfed (frequency varies)\n"
            "- **Temperature:** feel baby's chest — warm, not sweaty or cold\n\n"
            "### Cord care\n"
            "Keep stump dry. Sponge-bathe until it falls off (usually 1–3 weeks). No pulling.\n\n"
            "### Call your doctor if\n"
            "Baby is very sleepy and hard to wake for feeds, has fewer wet nappies, skin/eyes look more yellow, "
            "or temperature is above 38°C."
        ),
    },
    {
        "title": "Calcium and Vitamin D for Strong Bones",
        "summary": "Daily targets, Indian food sources, and why both matter for you and your baby's skeleton.",
        "category": "nutrition",
        "trimester": None,
        "week_min": 1,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["calcium", "vitamin_d", "nutrition", "bones"],
        "reading_time_min": 4,
        "source": "curated",
        "source_attribution": "WHO maternal nutrition guidance summary.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Calcium needs rise in the second and third trimesters.",
            "Curd, milk, ragi, sesame and green leafy vegetables are excellent sources.",
            "Safe sunlight exposure helps vitamin D — discuss supplements if indoors most of the day.",
        ],
        "body_markdown": (
            "Your baby builds most of its skeleton in the last trimester — drawing calcium from your diet and stores.\n\n"
            "### Daily food ideas\n"
            "- 2 cups milk or curd\n"
            "- 1 bowl ragi porridge or 2 small ragi rotis\n"
            "- Handful of sesame (til) or almonds\n"
            "- Cooked spinach, methi or drumstick leaves\n\n"
            "### Vitamin D\n"
            "10–15 minutes of morning sunlight on arms and face when safe. If you are vegetarian, mostly indoors, "
            "or have dark skin with low sun exposure, ask your doctor about a vitamin D test and supplement dose."
        ),
    },
    {
        "title": "Preparing for Labour: Breathing and Relaxation",
        "summary": "Simple techniques you can practise from week 32 to stay calmer during contractions.",
        "category": "exercise",
        "trimester": 3,
        "week_min": 32,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["labour", "breathing", "birth_prep", "third_trimester"],
        "reading_time_min": 4,
        "source": "curated",
        "source_attribution": "Based on respectful maternity care principles (WHO/PAHO quality-of-care framework).",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Slow exhale-longer-than-inhale breathing reduces panic during contractions.",
            "Practise for 5–10 minutes daily from week 32.",
            "Your birth partner can count breaths with you.",
        ],
        "body_markdown": (
            "### Box breathing (4-4-6)\n"
            "Inhale through the nose for 4 counts → hold 4 → exhale for 6. Repeat 10 cycles.\n\n"
            "### During a contraction\n"
            "Drop your shoulders, unclench your jaw, and focus only on the **out-breath**. "
            "Between contractions, sip water and rest completely.\n\n"
            "### Partner tip\n"
            "Eye contact + slow counting out loud is more helpful than 'push harder'. "
            "Discuss your preferences in a simple birth plan with your doctor."
        ),
    },
    {
        "title": "High Blood Pressure in Pregnancy: What Mothers Should Know",
        "summary": "Gestational hypertension, pre-eclampsia warning signs, and home monitoring tips.",
        "category": "emergency",
        "trimester": None,
        "week_min": 20,
        "week_max": 42,
        "condition_tags": ["high_bp", "pre_eclampsia"],
        "tags": ["blood_pressure", "pre_eclampsia", "hypertension"],
        "reading_time_min": 5,
        "source": "curated",
        "source_attribution": "WHO recommendations on hypertensive disorders in pregnancy (summary).",
        "severity": "warning",
        "doctor_approved": True,
        "key_takeaways": [
            "Attend every antenatal BP check — high BP often has no symptoms early on.",
            "Headache + vision changes + sudden swelling is an emergency triad.",
            "Take prescribed medicines on time; stopping without advice is risky.",
        ],
        "body_markdown": (
            "Blood pressure can rise in the second half of pregnancy even if you were healthy before.\n\n"
            "### Warning combination (call doctor same day)\n"
            "- Severe headache that does not improve with rest\n"
            "- Blurred vision or flashing lights\n"
            "- Sudden swelling of face and hands\n"
            "- Pain just below the ribs on the right side\n\n"
            "### At home\n"
            "Rest on your left side, reduce added salt in packaged snacks, and keep a log of home BP readings "
            "if your doctor has asked you to monitor."
        ),
    },
    {
        "title": "Dental Care During Pregnancy",
        "summary": "Why gum health matters, safe treatments, and morning-sickness-friendly oral care.",
        "category": "general",
        "trimester": None,
        "week_min": 1,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["dental", "gums", "oral_health"],
        "reading_time_min": 3,
        "source": "curated",
        "source_attribution": "Adapted from public oral-health-in-pregnancy guidance.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Routine dental check-ups are safe and recommended.",
            "Pregnancy hormones can make gums bleed more easily.",
            "Rinse with water after vomiting before brushing to protect enamel.",
        ],
        "body_markdown": (
            "Gum inflammation (pregnancy gingivitis) is common. Untreated gum disease is linked to preterm birth risk "
            "in some studies, so do not skip dental care.\n\n"
            "### Tips\n"
            "- Brush twice daily with a soft brush\n"
            "- Floss gently once a day\n"
            "- Tell your dentist you are pregnant — local anaesthetic and most treatments are safe\n"
            "- After morning sickness, rinse with plain water, wait 30 minutes, then brush"
        ),
    },
    {
        "title": "Partner and Family Support During Pregnancy",
        "summary": "Practical ways loved ones can help across trimesters and after birth.",
        "category": "mental_health",
        "trimester": None,
        "week_min": 1,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["partner", "support", "family", "wellbeing"],
        "reading_time_min": 4,
        "source": "curated",
        "source_attribution": "Aligned with WHO respectful maternity care and family-centred care principles.",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Emotional support lowers stress and improves attendance at antenatal visits.",
            "Share this app's appointment and diet tools with your partner.",
            "After birth, protected sleep shifts for the mother are a practical gift.",
        ],
        "body_markdown": (
            "### First trimester\n"
            "Help with nausea triggers — cooking smells, heavy chores. Attend the first scan if possible.\n\n"
            "### Second trimester\n"
            "Join a walk, learn warning signs together, discuss budget and leave plans.\n\n"
            "### Third trimester & postpartum\n"
            "Pack the hospital bag together, know the route to the hospital, and plan who handles night feeds "
            "so the mother can get 3–4 hour sleep blocks.\n\n"
            "Free online learning for families: WHO maternal health topics and PAHO's *Respectful Maternity and "
            "Newborn Care* course (Campus PAHO) cover rights-based, dignified care."
        ),
    },
    {
        "title": "Staying Active in the Third Trimester",
        "summary": "Safe movement, pelvic floor work, and signs to stop exercising.",
        "category": "exercise",
        "trimester": 3,
        "week_min": 28,
        "week_max": 42,
        "condition_tags": [],
        "tags": ["exercise", "walking", "pelvic_floor", "third_trimester"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Short daily walks aid sleep, mood and stamina for labour.",
            "Pelvic floor exercises (Kegels) support recovery after birth.",
            "Stop if you have bleeding, fluid leak, dizziness or painful contractions.",
        ],
        "body_markdown": (
            "### Good choices\n"
            "- 15–25 minute walks on flat ground\n"
            "- Prenatal yoga with pregnancy-safe modifications\n"
            "- Gentle stretching for hips and lower back\n"
            "- Pelvic floor lifts: 10 slow reps, 3 times daily\n\n"
            "### Stop and rest if\n"
            "You feel chest pain, calf swelling on one leg, vaginal bleeding, or regular painful contractions."
        ),
    },
    {
        "title": "Understanding Your Anomaly Scan (18–22 Weeks)",
        "summary": "What the mid-pregnancy ultrasound checks and how to prepare for the appointment.",
        "category": "baby_dev",
        "trimester": 2,
        "week_min": 18,
        "week_max": 22,
        "condition_tags": [],
        "tags": ["ultrasound", "anomaly_scan", "second_trimester"],
        "reading_time_min": 4,
        "source": "curated",
        "severity": "info",
        "doctor_approved": True,
        "key_takeaways": [
            "Usually done between weeks 18 and 22.",
            "Checks baby's organs, placenta position, and fluid level.",
            "A full bladder is not always needed — follow your hospital's instructions.",
        ],
        "body_markdown": (
            "The anomaly scan (level-2 ultrasound) is a detailed look at your baby's structure and growth.\n\n"
            "### It typically reviews\n"
            "- Brain, spine, heart, stomach, kidneys and limbs\n"
            "- Placenta position and amniotic fluid\n"
            "- Cervical length in some high-risk pregnancies\n\n"
            "Most results are reassuring. If something needs follow-up, your doctor will explain the next steps — "
            "many findings only need a repeat scan or a specialist opinion."
        ),
    },
]


# ---------------------------------------------------------------------------
# FAQs
# ---------------------------------------------------------------------------

_FAQS: list[dict] = [
    # Symptoms
    {
        "question": "Is nausea normal during pregnancy?",
        "answer_markdown": (
            "Yes — about 7 out of 10 mothers feel nauseous in the first trimester. "
            "It usually eases after week 14. Eating small frequent meals, ginger and "
            "lemon often help. **If you can't keep any food or water down for 24 hours, "
            "lose weight or vomit blood, contact your doctor the same day.**"
        ),
        "category": "symptoms", "trimester": 1, "severity": "info",
        "keywords": ["nausea", "vomiting", "morning", "sickness", "queasy"],
    },
    {
        "question": "Why am I so tired all the time?",
        "answer_markdown": (
            "Fatigue is common, especially in the first and third trimesters. Your body is producing "
            "extra blood and your hormones change rapidly. Try to sleep 7–9 hours, take short rests "
            "during the day, and check that your iron levels are healthy."
        ),
        "category": "symptoms", "trimester": None, "severity": "info",
        "keywords": ["tired", "fatigue", "exhausted", "sleepy"],
    },
    {
        "question": "Is swelling in my feet dangerous?",
        "answer_markdown": (
            "Mild ankle and foot swelling, especially in the evening, is common. "
            "**Sudden swelling of the face or hands, combined with headache or blurred vision, "
            "can be a sign of pre-eclampsia — please contact your doctor immediately.**"
        ),
        "category": "symptoms", "trimester": 3, "severity": "warning",
        "keywords": ["swelling", "swollen", "feet", "ankles", "puffy", "edema"],
    },
    {
        "question": "Why do I have heartburn?",
        "answer_markdown": (
            "Pregnancy hormones relax the valve at the top of the stomach, letting acid back up. "
            "Eat smaller meals, avoid spicy/oily food, and don't lie down for 1 hour after eating. "
            "Sleeping propped up on extra pillows helps."
        ),
        "category": "symptoms", "trimester": 2, "severity": "info",
        "keywords": ["heartburn", "acidity", "reflux", "burning"],
    },
    # Diet
    {
        "question": "Can I drink coffee during pregnancy?",
        "answer_markdown": (
            "Most guidelines suggest limiting caffeine to about 200 mg per day — roughly one mug of brewed coffee, "
            "or two cups of tea. High caffeine intake is linked to lower birth weight."
        ),
        "category": "diet", "trimester": None, "severity": "info",
        "keywords": ["coffee", "caffeine", "tea", "drink"],
    },
    {
        "question": "How much water should I drink?",
        "answer_markdown": (
            "Aim for 2.5–3 litres a day. Slightly more in the third trimester or in hot weather. "
            "Sip steadily through the day rather than gulping large amounts at once."
        ),
        "category": "diet", "trimester": None, "severity": "info",
        "keywords": ["water", "hydration", "thirsty", "drink", "fluids"],
    },
    {
        "question": "Which fruits are best in pregnancy?",
        "answer_markdown": (
            "Most fruits are great. Especially helpful are oranges and citrus (vitamin C), pomegranate "
            "and dates (iron), bananas (potassium) and berries (antioxidants). Wash all fruit thoroughly. "
            "Mothers with gestational diabetes should keep portions to one small bowl at a time."
        ),
        "category": "diet", "trimester": None, "severity": "info",
        "keywords": ["fruit", "fruits", "eat", "best"],
    },
    {
        "question": "Which foods should I avoid?",
        "answer_markdown": (
            "Avoid: raw or undercooked meat and eggs, unpasteurised milk and cheese, high-mercury fish "
            "(king mackerel, swordfish), liver in large amounts, sprouts not cooked, and alcohol. Cut down on "
            "sugary drinks and processed snacks."
        ),
        "category": "diet", "trimester": None, "severity": "info",
        "keywords": ["avoid", "foods", "unsafe", "dangerous", "raw"],
    },
    {
        "question": "Are pregnancy supplements really necessary?",
        "answer_markdown": (
            "Most mothers benefit from folic acid (first trimester), iron and calcium (second and third trimesters). "
            "Take only what your doctor prescribes — extra is not better and some vitamins are unsafe in high doses."
        ),
        "category": "diet", "trimester": None, "severity": "info",
        "keywords": ["supplement", "vitamins", "iron", "calcium", "tablets"],
    },
    # Exercise
    {
        "question": "Is it safe to walk daily?",
        "answer_markdown": (
            "Yes — walking is one of the safest and most useful exercises in pregnancy. Aim for 20–30 minutes "
            "most days. Slow down or rest if you feel breathless, dizzy or have any pain or bleeding."
        ),
        "category": "exercise", "trimester": None, "severity": "info",
        "keywords": ["walk", "walking", "exercise", "daily"],
    },
    {
        "question": "Is prenatal yoga safe?",
        "answer_markdown": (
            "Prenatal yoga taught by an instructor experienced with pregnancy is safe and often very helpful. "
            "Skip deep twists, lying flat on the back after week 16, and any poses that compress the belly."
        ),
        "category": "exercise", "trimester": None, "severity": "info",
        "keywords": ["yoga", "stretch", "exercise"],
    },
    {
        "question": "Which exercises should I avoid?",
        "answer_markdown": (
            "Avoid: contact sports, horse riding, skiing, scuba diving, hot yoga, sit-ups after the first trimester "
            "and any movement that involves holding your breath or jumping vigorously."
        ),
        "category": "exercise", "trimester": None, "severity": "warning",
        "keywords": ["avoid", "exercise", "unsafe", "sports"],
    },
    # Baby development
    {
        "question": "When will I feel my baby's first kicks?",
        "answer_markdown": (
            "First-time mothers usually feel kicks between weeks 18 and 22. Mothers who have had a baby before "
            "may notice movements a few weeks earlier. Early flutters can feel like gas bubbles."
        ),
        "category": "baby_development", "trimester": 2, "severity": "info",
        "keywords": ["kick", "kicks", "movement", "first", "feel"],
    },
    {
        "question": "How fast does my baby grow each week?",
        "answer_markdown": (
            "Growth varies, but at week 12 the baby is about 5 cm; at 20 weeks about 25 cm; at 30 weeks about 38 cm; "
            "and at 40 weeks about 50 cm. Weight gain is most rapid in the third trimester."
        ),
        "category": "baby_development", "trimester": None, "severity": "info",
        "keywords": ["grow", "growth", "size", "weight", "weeks"],
    },
    {
        "question": "Should I worry if I haven't felt the baby move today?",
        "answer_markdown": (
            "Before 24 weeks, occasional quiet days are normal. After 24 weeks, a clear drop from your baby's "
            "usual pattern is a warning sign. Drink something cold, lie on your left side and count movements for "
            "2 hours. **If less than 10 or still reduced, contact your doctor immediately.**"
        ),
        "category": "baby_development", "trimester": 3, "severity": "warning",
        "keywords": ["no", "movement", "baby", "not", "moving", "kicks"],
    },
    # Emergency
    {
        "question": "When should I go to the hospital?",
        "answer_markdown": (
            "Go to hospital or call your doctor immediately if you have **heavy bleeding, severe headache with "
            "blurred vision, continuous belly pain, fever above 38.5°C, your waters break, or the baby's movements "
            "have clearly reduced.**"
        ),
        "category": "emergency", "trimester": None, "severity": "emergency",
        "keywords": ["hospital", "emergency", "danger", "bleeding", "severe"],
    },
    {
        "question": "What symptoms are dangerous?",
        "answer_markdown": (
            "**Danger signs:** heavy bleeding, severe abdominal pain, severe headache that won't go away, "
            "blurred vision or seeing flashing lights, severe swelling of the face/hands, watery discharge before "
            "37 weeks, reduced baby movements after 28 weeks, fainting, and high fever."
        ),
        "category": "emergency", "trimester": None, "severity": "emergency",
        "keywords": ["danger", "dangerous", "symptoms", "warning"],
    },
    {
        "question": "Is bleeding ever normal in pregnancy?",
        "answer_markdown": (
            "Light spotting can occur, especially after sex or a vaginal exam. **Any bleeding heavy enough to soak "
            "a pad in an hour, or bright red bleeding with cramps, is not normal — call your doctor immediately.**"
        ),
        "category": "emergency", "trimester": None, "severity": "emergency",
        "keywords": ["bleeding", "blood", "spotting", "bright"],
    },
    # Mental health
    {
        "question": "Why am I crying for no reason?",
        "answer_markdown": (
            "Rapid hormone changes can make emotions feel bigger than usual. It's a normal part of pregnancy. "
            "Talk to someone you trust, get fresh air daily and try to keep a steady sleep routine. "
            "If sadness lasts more than 2 weeks, please talk to your doctor."
        ),
        "category": "mental_health", "trimester": None, "severity": "info",
        "keywords": ["crying", "mood", "sad", "emotional"],
    },
    {
        "question": "Is it safe to have sex during pregnancy?",
        "answer_markdown": (
            "In an uncomplicated pregnancy, yes — sex is safe. Avoid it if your doctor has flagged risks such as "
            "placenta previa, preterm labour or unexplained bleeding."
        ),
        "category": "general", "trimester": None, "severity": "info",
        "keywords": ["sex", "intimacy", "intercourse"],
    },
    {
        "question": "Can I travel by air during pregnancy?",
        "answer_markdown": (
            "Most airlines allow flying up to 36 weeks for an uncomplicated single pregnancy (32 weeks for twins). "
            "On long flights, walk around every hour, stay hydrated and wear compression stockings to reduce clot risk."
        ),
        "category": "general", "trimester": None, "severity": "info",
        "keywords": ["travel", "fly", "flight", "air"],
    },
    {
        "question": "When should I start preparing for labour?",
        "answer_markdown": (
            "Pack your hospital bag by week 35, finalise your birth plan with your doctor, and learn the early signs "
            "of labour. Practising breathing techniques weekly from week 32 helps a lot."
        ),
        "category": "general", "trimester": 3, "severity": "info",
        "keywords": ["labour", "labor", "delivery", "prepare", "hospital", "bag"],
    },
    {
        "question": "Which vaccines should I get during pregnancy?",
        "answer_markdown": (
            "Most guidelines recommend **influenza (flu)** in any trimester during flu season and **Tdap (whooping cough)** "
            "between weeks 27–36. COVID-19 and RSV vaccines depend on your country and season — ask at your antenatal visit. "
            "Inactivated vaccines are generally safe; live vaccines are usually avoided in pregnancy."
        ),
        "category": "general", "trimester": None, "severity": "info",
        "keywords": ["vaccine", "vaccines", "flu", "tdap", "immunization", "injection"],
    },
    {
        "question": "How do I know if breastfeeding is going well?",
        "answer_markdown": (
            "Good signs: baby feeds 8–12 times per day, you hear swallowing, and after day 4–5 you see at least 6 wet nappies "
            "in 24 hours. **Get help same day if** nipples crack or bleed, baby is very sleepy and hard to wake, or you have "
            "fever with a painful hard breast."
        ),
        "category": "general", "trimester": None, "severity": "info",
        "keywords": ["breastfeeding", "breastfeed", "latch", "milk", "nursing"],
    },
    {
        "question": "Is heavy bleeding normal after birth?",
        "answer_markdown": (
            "Bleeding is heaviest in the first few days and should gradually lighten over 4–6 weeks. "
            "**Not normal:** soaking more than one pad per hour, passing golf-ball-sized clots, or foul-smelling discharge "
            "with fever — contact your doctor or go to hospital immediately."
        ),
        "category": "emergency", "trimester": None, "severity": "warning",
        "keywords": ["postpartum", "bleeding", "after", "birth", "lochia"],
    },
    {
        "question": "What is the difference between baby blues and postpartum depression?",
        "answer_markdown": (
            "**Baby blues** — tearfulness and mood swings in the first 2 weeks that come and go. "
            "**Postpartum depression** — low mood most days for more than 2 weeks, guilt, poor sleep even when baby sleeps, "
            "or thoughts of self-harm. Use the EPDS screening in LifeNest and talk to your doctor — treatment works."
        ),
        "category": "mental_health", "trimester": None, "severity": "warning",
        "keywords": ["depression", "baby", "blues", "postpartum", "sad", "EPDS"],
    },
]


# ---------------------------------------------------------------------------
# Daily tips
# ---------------------------------------------------------------------------

_TIPS: list[dict] = [
    # Trimester 1
    ("Eat small meals every 2 hours to ease morning sickness.", 1, 4, 14, [], "nutrition"),
    ("Sip warm water with a slice of ginger first thing in the morning.", 1, 4, 14, ["morning_sickness"], "nutrition"),
    ("Take your folic acid every day this week — it builds your baby's brain.", 1, 1, 13, [], "nutrition"),
    ("Add a leafy green vegetable to one meal today.", 1, 1, 13, [], "nutrition"),
    ("Lie down for 20 minutes in the afternoon if you can — fatigue is real.", 1, 5, 14, [], "wellness"),
    # Trimester 2
    ("Drink at least 2.5 litres of water today.", 2, 14, 27, [], "wellness"),
    ("Take a 20-minute walk after lunch — gentle and energising.", 2, 14, 27, [], "exercise"),
    ("Pair iron foods with a squeeze of lemon for better absorption.", 2, 14, 27, ["anemia"], "nutrition"),
    ("Add 1 cup of curd or paneer today for calcium.", 2, 14, 27, [], "nutrition"),
    ("Talk or sing to your baby — by week 18 they can hear you.", 2, 18, 27, [], "wellness"),
    # Trimester 3
    ("Sleep on your left side for better blood flow to the baby.", 3, 28, 42, [], "wellness"),
    ("Count baby movements after dinner — 10 in 2 hours is reassuring.", 3, 28, 42, [], "wellness"),
    ("Pack your hospital bag this weekend if you haven't yet.", 3, 33, 42, [], "general"),
    ("Practise slow breathing: 4 seconds in, 6 seconds out — 10 minutes today.", 3, 28, 42, [], "wellness"),
    ("Avoid standing for long stretches — swelling is more likely now.", 3, 28, 42, [], "wellness"),
    # Condition-specific
    ("Carry roasted chana or dates as a snack — light, iron-rich and easy.", None, 1, 42, ["anemia"], "nutrition"),
    ("Skip white rice today — try millets or brown rice for steadier blood sugar.", None, 20, 42, ["gestational_diabetes"], "nutrition"),
    ("Reduce salt in your meals today and increase water intake.", None, 1, 42, ["high_bp"], "nutrition"),
    # Postpartum & newborn
    ("Skin-to-skin with your baby for 15 minutes after a feed builds bonding and milk supply.", None, 37, 42, [], "wellness"),
    ("Ask your partner to handle one night feed so you can get a 3-hour sleep block.", None, 37, 42, [], "wellness"),
    ("Check baby's wet nappies — 6+ per day after day 4 means feeding is on track.", None, 37, 42, [], "wellness"),
    ("Discuss Tdap and flu vaccines at your next antenatal visit if you haven't had them.", None, 27, 42, [], "general"),
]


def seed_education(db: Session) -> dict[str, int]:
    """Insert any missing curated articles, FAQs and daily tips."""
    counts = {"articles": 0, "faqs": 0, "tips": 0}

    for item in _ARTICLES:
        existing = db.query(Article).filter(Article.title == item["title"]).first()
        if existing is not None:
            continue
        db.add(Article(
            title=item["title"],
            summary=item.get("summary"),
            body_markdown=item["body_markdown"],
            category=item["category"],
            trimester=item.get("trimester"),
            week_min=item.get("week_min"),
            week_max=item.get("week_max"),
            condition_tags=_j(item.get("condition_tags", [])),
            tags=_j(item.get("tags", [])),
            reading_time_min=item.get("reading_time_min", 3),
            source=item.get("source", "curated"),
            source_attribution=item.get("source_attribution"),
            severity=item.get("severity", "info"),
            doctor_approved=item.get("doctor_approved", True),
            key_takeaways=_j(item.get("key_takeaways", [])),
            is_published=True,
        ))
        counts["articles"] += 1

    for item in _FAQS:
        existing = db.query(Faq).filter(Faq.question == item["question"]).first()
        if existing is not None:
            continue
        db.add(Faq(
            question=item["question"],
            answer_markdown=item["answer_markdown"],
            category=item["category"],
            trimester=item.get("trimester"),
            keywords=_j(item.get("keywords", [])),
            severity=item.get("severity", "info"),
            related_article_ids=_j([]),
            doctor_approved=True,
            is_published=True,
        ))
        counts["faqs"] += 1

    for (text, trimester, wmin, wmax, conds, category) in _TIPS:
        existing = db.query(DailyTip).filter(DailyTip.tip_text == text).first()
        if existing is not None:
            continue
        db.add(DailyTip(
            tip_text=text,
            trimester=trimester,
            week_min=wmin,
            week_max=wmax,
            condition_tags=_j(conds),
            category=category,
            is_published=True,
        ))
        counts["tips"] += 1

    if any(counts.values()):
        db.commit()
        log.info("Seeded education: %s", counts)
    return counts
