#!/usr/bin/env python3
"""
FILE: scripts/generate_category_embeddings.py
VERSION: 1.0.0
DESCRIPTION: Generates pre-computed category embeddings for semantic matching.
             Run once offline, output used by Rust/Flutter for local matching.
"""

import json
import numpy as np

# Check if sentence-transformers is available
try:
    from sentence_transformers import SentenceTransformer
    HAS_SENTENCE_TRANSFORMERS = True
except ImportError:
    HAS_SENTENCE_TRANSFORMERS = False
    print("Note: sentence-transformers not installed. Using mock embeddings for development.")

# 100+ Categories with synonym lists for robust matching
CATEGORIES = {
    # PEOPLE
    "PERSON": ["person", "human", "individual", "man", "woman", "child", "adult", "people"],
    "FACE": ["face", "facial features", "portrait", "headshot"],
    
    # CLOTHING - Upper Body
    "SHIRT": ["shirt", "t-shirt", "blouse", "top", "polo", "button-down", "dress shirt", "tee"],
    "OUTERWEAR": ["jacket", "coat", "blazer", "hoodie", "sweater", "cardigan", "windbreaker", "parka"],
    "SUIT": ["suit", "tuxedo", "formal wear", "business suit", "suit jacket"],
    
    # CLOTHING - Lower Body
    "PANTS": ["pants", "trousers", "jeans", "slacks", "chinos", "khakis", "joggers"],
    "SHORTS": ["shorts", "bermuda shorts", "running shorts", "swim shorts"],
    "SKIRT": ["skirt", "mini skirt", "maxi skirt", "pencil skirt"],
    "DRESS": ["dress", "gown", "evening dress", "sundress", "cocktail dress"],
    
    # FOOTWEAR
    "FOOTWEAR": ["shoes", "sneakers", "boots", "sandals", "trainers", "running shoes", "loafers", "heels"],
    "ATHLETIC_SHOES": ["running shoes", "sports shoes", "athletic footwear", "training shoes"],
    "FORMAL_SHOES": ["dress shoes", "oxford shoes", "loafers", "brogues", "formal footwear"],
    
    # ACCESSORIES
    "GLASSES": ["glasses", "spectacles", "eyeglasses", "reading glasses", "sunglasses", "eyewear"],
    "JEWELRY": ["jewelry", "watch", "bracelet", "necklace", "ring", "earrings", "pendant"],
    "HEADWEAR": ["hat", "cap", "beanie", "beret", "fedora", "baseball cap", "headgear"],
    "BAG": ["bag", "backpack", "purse", "handbag", "messenger bag", "tote", "briefcase", "luggage"],
    "BELT": ["belt", "waist belt", "leather belt", "dress belt"],
    "SCARF": ["scarf", "shawl", "wrap", "muffler", "neckerchief"],
    "TIE": ["tie", "necktie", "bow tie", "cravat"],
    
    # ELECTRONICS - Computing
    "COMPUTER": ["computer", "laptop", "desktop", "PC", "workstation", "MacBook", "ThinkPad", "notebook"],
    "TABLET": ["tablet", "iPad", "Android tablet", "e-reader", "Kindle", "digital pad"],
    "PHONE": ["phone", "smartphone", "mobile phone", "iPhone", "Android phone", "cell phone", "mobile"],
    "SMARTWATCH": ["smartwatch", "Apple Watch", "fitness tracker", "wearable", "smart band"],
    
    # ELECTRONICS - Audio/Visual
    "HEADPHONES": ["headphones", "earphones", "earbuds", "AirPods", "headset", "audio gear"],
    "SPEAKER": ["speaker", "Bluetooth speaker", "soundbar", "audio system", "smart speaker"],
    "TV": ["television", "TV", "monitor", "display", "screen", "smart TV"],
    "CAMERA": ["camera", "digital camera", "DSLR", "mirrorless camera", "video camera", "webcam"],
    
    # ELECTRONICS - Gaming
    "GAMING": ["gaming console", "PlayStation", "Xbox", "Nintendo", "game controller", "gaming"],
    "VR_HEADSET": ["VR headset", "virtual reality", "Oculus", "Meta Quest", "VR glasses"],
    
    # ELECTRONICS - Others
    "CHARGER": ["charger", "power adapter", "charging cable", "USB cable", "power bank"],
    "REMOTE": ["remote control", "TV remote", "remote", "controller"],
    
    # STATIONERY & OFFICE
    "NOTEBOOK": ["notebook", "notepad", "journal", "diary", "sketchbook", "writing pad"],
    "BOOK": ["book", "textbook", "novel", "reading material", "paperback", "hardcover"],
    "WRITING": ["pen", "pencil", "marker", "highlighter", "writing instrument", "stylus"],
    "DOCUMENT": ["document", "paper", "letter", "certificate", "contract", "form", "file"],
    "OFFICE_SUPPLIES": ["stapler", "scissors", "tape", "paperclip", "binder", "folder"],
    
    # FURNITURE - Seating
    "CHAIR": ["chair", "seat", "stool", "armchair", "office chair", "dining chair", "recliner"],
    "SOFA": ["sofa", "couch", "loveseat", "sectional", "settee", "futon"],
    
    # FURNITURE - Surfaces
    "TABLE": ["table", "desk", "dining table", "coffee table", "work desk", "writing desk"],
    "BED": ["bed", "mattress", "bedframe", "bunk bed", "sleeping furniture"],
    "SHELF": ["shelf", "bookshelf", "storage shelf", "display shelf", "rack"],
    "CABINET": ["cabinet", "cupboard", "wardrobe", "closet", "storage unit", "dresser"],
    
    # FURNITURE - Others
    "WINDOW": ["window", "curtain", "blinds", "drapes", "window covering"],
    "DOOR": ["door", "doorway", "entrance", "gate"],
    "LAMP": ["lamp", "light fixture", "desk lamp", "floor lamp", "lighting"],
    "MIRROR": ["mirror", "looking glass", "vanity mirror", "wall mirror"],
    
    # KITCHEN - Appliances
    "REFRIGERATOR": ["refrigerator", "fridge", "freezer", "cooler"],
    "MICROWAVE": ["microwave", "microwave oven", "heating appliance"],
    "OVEN": ["oven", "stove", "range", "cooking appliance", "toaster oven"],
    "BLENDER": ["blender", "mixer", "food processor", "juicer"],
    "COFFEE_MAKER": ["coffee maker", "espresso machine", "coffee machine", "kettle"],
    
    # KITCHEN - Utensils & Cookware
    "COOKWARE": ["pot", "pan", "skillet", "wok", "saucepan", "cooking pot"],
    "KNIFE": ["knife", "kitchen knife", "cutting tool", "chef knife", "blade"],
    "UTENSILS": ["spatula", "ladle", "spoon", "fork", "cooking utensils", "cutlery"],
    
    # KITCHEN - Dinnerware
    "DRINKWARE": ["glass", "cup", "mug", "bottle", "tumbler", "water bottle", "drinking vessel"],
    "DINNERWARE": ["plate", "bowl", "dish", "saucer", "serving plate", "dinnerware"],
    
    # FOOD & BEVERAGES
    "FOOD": ["food", "meal", "dish", "cuisine", "snack", "prepared food"],
    "FRUIT": ["fruit", "apple", "banana", "orange", "berries", "fresh fruit"],
    "VEGETABLE": ["vegetable", "vegetables", "salad", "greens", "produce"],
    "BEVERAGE": ["drink", "beverage", "juice", "soda", "water", "coffee", "tea"],
    "PACKAGED_FOOD": ["packaged food", "snacks", "chips", "crackers", "boxed food"],
    
    # VEHICLES
    "VEHICLE": ["car", "vehicle", "automobile", "auto", "sedan", "SUV", "truck"],
    "MOTORCYCLE": ["motorcycle", "bike", "motorbike", "scooter", "moped"],
    "BICYCLE": ["bicycle", "bike", "cycle", "mountain bike", "road bike", "cycling"],
    "BUS": ["bus", "coach", "shuttle", "public transport"],
    "TRAIN": ["train", "railway", "metro", "subway", "locomotive"],
    "AIRPLANE": ["airplane", "aircraft", "plane", "jet", "aviation"],
    "BOAT": ["boat", "ship", "yacht", "vessel", "watercraft"],
    
    # SPORTS & FITNESS
    "SPORTS_EQUIPMENT": ["sports equipment", "athletic gear", "sports gear"],
    "BALL": ["ball", "soccer ball", "basketball", "football", "tennis ball", "sports ball"],
    "RACKET": ["racket", "tennis racket", "badminton racket", "paddle"],
    "GYM_EQUIPMENT": ["dumbbell", "weights", "gym equipment", "exercise equipment", "barbell"],
    "YOGA": ["yoga mat", "yoga equipment", "exercise mat", "fitness mat"],
    
    # NATURE & OUTDOORS
    "PLANT": ["plant", "flower", "tree", "vegetation", "houseplant", "greenery", "potted plant"],
    "ANIMAL": ["animal", "pet", "dog", "cat", "bird", "wildlife"],
    "INSECT": ["insect", "bug", "butterfly", "bee", "spider"],
    
    # TOOLS & HARDWARE
    "TOOL": ["tool", "hardware", "equipment", "instrument"],
    "HAMMER": ["hammer", "mallet", "striking tool"],
    "SCREWDRIVER": ["screwdriver", "driver", "turning tool"],
    "WRENCH": ["wrench", "spanner", "socket wrench"],
    "DRILL": ["drill", "power drill", "electric drill", "drilling tool"],
    
    # MEDICAL
    "MEDICINE": ["medicine", "medication", "pills", "tablets", "pharmaceutical", "drug"],
    "MEDICAL_DEVICE": ["medical device", "thermometer", "blood pressure monitor", "medical equipment"],
    "FIRST_AID": ["first aid kit", "bandage", "medical supplies", "emergency kit"],
    
    # PERSONAL CARE
    "COSMETICS": ["cosmetics", "makeup", "beauty products", "skincare", "lipstick", "foundation"],
    "TOILETRIES": ["toiletries", "soap", "shampoo", "toothbrush", "personal hygiene"],
    "PERFUME": ["perfume", "fragrance", "cologne", "scent", "eau de toilette"],
    
    # BABY & KIDS
    "TOY": ["toy", "plaything", "children's toy", "game", "puzzle", "action figure"],
    "BABY_GEAR": ["stroller", "car seat", "baby carrier", "crib", "baby equipment"],
    
    # HOME & GARDEN
    "CLEANING": ["cleaning supplies", "broom", "mop", "vacuum", "cleaning equipment"],
    "GARDENING": ["gardening tools", "shovel", "rake", "garden equipment", "planter"],
    
    # ART & CRAFT
    "ART_SUPPLIES": ["art supplies", "paint", "canvas", "brush", "crafting materials"],
    "MUSICAL_INSTRUMENT": ["musical instrument", "guitar", "piano", "violin", "drums", "keyboard"],
    
    # PACKAGING
    "BOX": ["box", "package", "carton", "shipping box", "container"],
    "BAG_PACKAGING": ["shopping bag", "plastic bag", "paper bag", "packaging"],
    
    # CURRENCY & FINANCE
    "MONEY": ["money", "cash", "currency", "banknotes", "coins"],
    "CARD": ["card", "credit card", "debit card", "ID card", "business card"],
    
    # SIGNAGE
    "SIGN": ["sign", "signage", "billboard", "poster", "banner", "notice"],
    "LOGO": ["logo", "brand logo", "company logo", "trademark", "brand mark"],
    
    # GENERIC FALLBACK
    "OBJECT": ["object", "item", "thing", "stuff", "material", "product", "generic item"],
}

def generate_embeddings():
    """Generate embeddings for all categories."""
    
    if HAS_SENTENCE_TRANSFORMERS:
        print("Loading sentence-transformers model (all-MiniLM-L6-v2)...")
        model = SentenceTransformer('all-MiniLM-L6-v2')
        
        category_embeddings = {}
        
        for category, synonyms in CATEGORIES.items():
            print(f"  Generating embedding for {category}...")
            # Generate embeddings for all synonyms
            embeddings = model.encode(synonyms)
            # Average them for robustness
            avg_embedding = np.mean(embeddings, axis=0)
            # Normalize
            avg_embedding = avg_embedding / np.linalg.norm(avg_embedding)
            category_embeddings[category] = avg_embedding.tolist()
        
        return category_embeddings, 384  # MiniLM has 384 dimensions
    else:
        # Mock embeddings for development
        print("Generating mock embeddings (384 dimensions)...")
        category_embeddings = {}
        np.random.seed(42)  # Reproducible
        
        for category in CATEGORIES.keys():
            # Generate deterministic mock embedding based on category name
            embedding = np.random.randn(384)
            embedding = embedding / np.linalg.norm(embedding)
            category_embeddings[category] = embedding.tolist()
        
        return category_embeddings, 384

def main():
    print("=" * 60)
    print("SatyaSetu Category Embeddings Generator")
    print("=" * 60)
    
    embeddings, dimensions = generate_embeddings()
    
    # Create output structure
    output = {
        "version": "1.0.0",
        "model": "all-MiniLM-L6-v2" if HAS_SENTENCE_TRANSFORMERS else "mock",
        "dimensions": dimensions,
        "categories_count": len(embeddings),
        "categories": list(embeddings.keys()),
        "embeddings": embeddings
    }
    
    # Save to JSON
    output_path = "../flutter_app/assets/category_embeddings.json"
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\n✓ Generated {len(embeddings)} category embeddings")
    print(f"✓ Dimensions: {dimensions}")
    print(f"✓ Saved to: {output_path}")
    
    # Also save a compact version (no indentation) for production
    compact_path = "../flutter_app/assets/category_embeddings.min.json"
    with open(compact_path, 'w') as f:
        json.dump(output, f, separators=(',', ':'))
    
    print(f"✓ Compact version: {compact_path}")
    
    # Print file sizes
    import os
    size_pretty = os.path.getsize(output_path) / 1024
    size_compact = os.path.getsize(compact_path) / 1024
    print(f"\n  Pretty size: {size_pretty:.1f} KB")
    print(f"  Compact size: {size_compact:.1f} KB")

if __name__ == "__main__":
    main()
