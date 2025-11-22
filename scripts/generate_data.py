#!/usr/bin/env python3
"""
E-Commerce Data Generator
"""

import os
import sys
import csv
import random
import hashlib
import uuid as uuid_module
from datetime import datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from collections import defaultdict
from typing import List, Dict, Tuple

# ============================================================================
# OPTIONAL: Progress bar (tqdm)
# ============================================================================
try:
    from tqdm import tqdm
    TQDM_AVAILABLE = True
except ImportError:
    print("⚠️  tqdm not available. Install with: pip install tqdm")
    TQDM_AVAILABLE = False

# ============================================================================
# OPTIONAL: Faker library for realistic data
# ============================================================================
try:
    from faker import Faker
    fake = Faker()
    Faker.seed(42)  # Reproducible fake data
except ImportError:
    print("⚠️  faker not available. Install with: pip install faker")
    sys.exit(1)

# ============================================================================
# OPTIONAL: PostgreSQL support
# ============================================================================
try:
    import psycopg2
    from psycopg2.extras import execute_batch
    PSYCOPG2_AVAILABLE = True
except ImportError:
    print("⚠️  psycopg2 not available. Install with: pip install psycopg2-binary")
    PSYCOPG2_AVAILABLE = False

# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    # Output settings
    'output_dir': f'csv_output_{datetime.now().strftime("%Y%m%d_%H%M%S")}',
    'delimiter': '|',  # Pipe delimiter (safer for text fields)
    
    # Data volumes
    'num_consumers': 10000,
    'num_sellers': 1000,
    'num_commodities': 50000,
    'num_orders': 100000,
    
    # Ranges
    'address_per_consumer_range': (1, 3),
    'cards_per_consumer_range': (1, 3),
    'items_per_order_range': (1, 5),
    
    # PostgreSQL connection (optional)
    'postgres': {
        'host': 'localhost',
        'port': 5432,
        'database': 'e_commerce_simulator',
        'user': 'postgres',
        'password': 'postgres'
    },
    
    # Verticals master file (persistent across runs)
    'verticals_master_file': 'verticals_master.csv',
}

# Seed for reproducibility
random.seed(42)

# ============================================================================
# ENUMS (matching database schema)
# ============================================================================

ENUMS = {
    'status': ['active', 'inactive', 'deleted'],
    'gender': ['male', 'female', 'prefer not to say', 'undefined'],
    'seller_type': ['vendor', 'authorized'],
    'verticals': [
        # Electronics & Technology (15)
        'smartphones', 'laptops', 'tablets', 'televisions', 'cameras', 'audio equipment',
        'wearables', 'gaming consoles', 'computer accessories', 'smart home devices',
        'drones', 'virtual reality', 'networking equipment', 'software', 'electronics accessories',
        
        # Fashion & Apparel (18)
        'womens clothing', 'mens clothing', 'kids clothing', 'shoes', 'bags & luggage',
        'watches', 'jewelry', 'sunglasses', 'hats & caps', 'belts & accessories',
        'activewear', 'swimwear', 'lingerie', 'formal wear', 'streetwear',
        'plus size fashion', 'maternity wear', 'traditional clothing',
        
        # Home & Living (16)
        'furniture', 'home decor', 'bedding', 'bath', 'kitchen & dining',
        'lighting', 'storage & organization', 'curtains & blinds', 'rugs & carpets',
        'wall art', 'indoor plants', 'home improvement', 'cleaning supplies',
        'laundry supplies', 'pest control', 'home security',
        
        # Health & Beauty (12)
        'skincare', 'makeup', 'haircare', 'fragrances', 'personal care',
        'medical supplies', 'vitamins & supplements', 'sexual wellness',
        'oral care', 'mens grooming', 'spa & relaxation', 'health monitors',
        
        # Food & Beverages (10)
        'groceries', 'beverages', 'snacks', 'gourmet food', 'organic food',
        'international cuisine', 'dietary supplements', 'baby food', 'pet food',
        'meal kits',
        
        # Sports & Outdoors (12)
        'fitness equipment', 'outdoor recreation', 'cycling', 'camping & hiking',
        'water sports', 'winter sports', 'team sports', 'yoga & pilates',
        'hunting & fishing', 'golf', 'tennis & racquet sports', 'sports nutrition',
        
        # Baby & Kids (8)
        'baby care', 'baby gear', 'baby toys', 'kids toys', 'kids books',
        'school supplies', 'kids furniture', 'kids safety',
        
        # Automotive (7)
        'car accessories', 'car electronics', 'car parts', 'motorcycle accessories',
        'car care', 'tools & equipment', 'tires & wheels',
        
        # Books & Media (6)
        'books', 'ebooks', 'audiobooks', 'magazines', 'movies & tv',
        'music & vinyl',
        
        # Hobbies & Crafts (10)
        'arts & crafts', 'sewing & fabric', 'painting supplies', 'musical instruments',
        'photography', 'collectibles', 'model building', 'scrapbooking',
        'party supplies', 'seasonal decor',
        
        # Pet Supplies (6)
        'dog supplies', 'cat supplies', 'bird supplies', 'fish & aquarium',
        'small animal supplies', 'reptile supplies',
        
        # Office & Stationery (7)
        'office supplies', 'stationery', 'office furniture', 'printers & ink',
        'business equipment', 'presentation supplies', 'desk accessories',
        
        # Garden & Outdoor (6)
        'gardening tools', 'plants & seeds', 'outdoor furniture', 'grills & outdoor cooking',
        'lawn care', 'outdoor lighting',
        
        # Appliances (5)
        'kitchen appliances', 'home appliances', 'air quality', 'vacuum cleaners',
        'small appliances',
        
        # Miscellaneous (8)
        'luggage & travel', 'gift cards', 'handmade products', 'vintage items',
        'refurbished products', 'wedding supplies', 'religious items', 'industrial supplies'
    ],
    'order_status': ['draft', 'inprogress', 'pending', 'shipped', 'delivered', 'done', 'cancelled', 'abandoned'],
    'trans_status': ['draft', 'authorized', 'captured', 'failed', 'refunded', 'cancelled'],
    'commodity_status': ['available', 'unavailable', 'out of stock', 'discontinued'],
    'review_status': ['draft', 'published', 'deleted', 'flagged'],
    'card_provider': ['visa', 'mastercard', 'jcb', 'diners', 'american_express', 'discover', 'unionpay'],
    'card_status': ['active', 'inactive', 'expired', 'anomaly', 'fraud'],
    'payment_method': ['card', 'cod', 'apple_pay', 'g_pay', 's_pay', 'paypal', 'bank_transfer'],
}

# Customer segmentation thresholds
CUSTOMER_SEGMENTS = {
    'VIP': 5000,        # > $5000 lifetime spend
    'Regular': 1000,    # > $1000
    'Occasional': 100,  # > $100
    'One-time': 0,      # Rest
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def generate_uuid() -> str:
    """Generate UUID v4"""
    return str(uuid_module.uuid4())

def generate_unique_sku() -> str:
    """Generate unique SKU (Stock Keeping Unit)"""
    prefix = random.choice(['ELEC', 'FASH', 'HOME', 'FOOD', 'SPRT', 'BABY', 'AUTO', 'BOOK'])
    number = random.randint(100000, 999999)
    return f"{prefix}-{number}"

def weighted_choice(choices: List[str], weights: List[float]) -> str:
    """Weighted random choice"""
    return random.choices(choices, weights=weights, k=1)[0]

def random_decimal(min_val: float, max_val: float, decimals: int = 2) -> Decimal:
    """Generate random decimal"""
    # Convert to float in case Decimal is passed
    min_val = float(min_val)
    max_val = float(max_val)
    value = random.uniform(min_val, max_val)
    return round(Decimal(str(value)), decimals)


def quantize_decimal(value: Decimal, decimals: int = 4) -> Decimal:
    """Quantize a Decimal to a fixed precision"""
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    quantizer = Decimal('1').scaleb(-decimals)
    return value.quantize(quantizer, rounding=ROUND_HALF_UP)


def format_decimal(value: Decimal, decimals: int = 4) -> str:
    """Format Decimal with fixed precision for CSV output"""
    return str(quantize_decimal(value, decimals=decimals))


def format_rating(value: Decimal) -> str:
    """Format rating values with two decimal places"""
    return format_decimal(value, decimals=2)

def random_date_in_range(days_back: int) -> datetime:
    """Generate random date within range"""
    return datetime.now() - timedelta(days=random.randint(0, days_back))

def format_timestamp(dt: datetime) -> str:
    """Format timestamp for CSV"""
    return dt.strftime('%Y-%m-%d %H:%M:%S')

def format_date(dt: datetime) -> str:
    """Format date for CSV"""
    return dt.strftime('%Y-%m-%d')

def clean_text_field(text: str) -> str:
    """Clean text field (remove pipes, newlines, quotes)"""
    if not text:
        return ''
    # Remove problematic characters
    text = text.replace('|', ' ')
    text = text.replace('\n', ' ')
    text = text.replace('\r', ' ')
    text = text.replace('"', "'")
    # Collapse multiple spaces
    text = ' '.join(text.split())
    return text.strip()

def calculate_customer_segment(total_spent: Decimal) -> str:
    """Calculate customer segment based on spending"""
    spent = float(total_spent)
    if spent >= CUSTOMER_SEGMENTS['VIP']:
        return 'VIP'
    elif spent >= CUSTOMER_SEGMENTS['Regular']:
        return 'Regular'
    elif spent >= CUSTOMER_SEGMENTS['Occasional']:
        return 'Occasional'
    else:
        return 'One-time'

def hash_card_number(card_number: str) -> str:
    """Hash card number (simulate tokenization)"""
    return hashlib.sha256(card_number.encode()).hexdigest()

# ============================================================================
# DATA GENERATION FUNCTIONS
# ============================================================================

def load_or_generate_verticals() -> List[Dict]:
    """
    Load verticals from persistent master file, or generate once if not exists.
    This ensures verticals are consistent across all data generation runs.
    """
    master_file = CONFIG['verticals_master_file']
    
    # Check if master file exists
    if os.path.exists(master_file):
        print(f"📦 Loading verticals from master file: {master_file}")
        verticals = []
        
        with open(master_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='|')
            for row in reader:
                verticals.append(row)
        
        print(f"✅ Loaded {len(verticals)} verticals from master file")
        print(f"   Verticals are consistent across all data generation runs")
        return verticals
    
    # Generate verticals for the first time
    print(f"📦 Generating verticals master file (first-time setup)...")
    print(f"   This file will be reused for all future data generation")
    verticals = []
    
    iterator = enumerate(ENUMS['verticals'])
    if TQDM_AVAILABLE:
        iterator = tqdm(list(iterator), desc="Creating verticals", unit="vertical")
    
    for i, name in iterator:
        vertical = {
            'id': generate_uuid(),
            'name': name,
            'description': clean_text_field(fake.text(max_nb_chars=200)),
            'status': weighted_choice(ENUMS['status'], [0.90, 0.08, 0.02]),
        }
        verticals.append(vertical)
    
    # Save to master file
    fieldnames = ['id', 'name', 'description', 'status']
    with open(master_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter='|')
        writer.writeheader()
        writer.writerows(verticals)
    
    print(f"✅ Created and saved {len(verticals)} verticals to {master_file}")
    print(f"   ⚠️  DO NOT delete this file - it ensures vertical consistency")
    
    return verticals

def generate_users_and_consumers() -> Tuple[List[Dict], List[Dict]]:
    """Generate users and consumer profiles"""
    print(f"👥 Generating {CONFIG['num_consumers']} consumers...")
    users = []
    consumers = []
    
    iterator = range(CONFIG['num_consumers'])
    if TQDM_AVAILABLE:
        iterator = tqdm(iterator, desc="Creating consumers", unit="consumer")
    
    for i in iterator:
        user_id = generate_uuid()
        
        # User record
        user = {
            'id': user_id,
            'username': fake.user_name() + str(random.randint(100, 9999)),
            'phone': fake.phone_number()[:15],
            'name': clean_text_field(fake.name()[:100]),
            'email': fake.email(),
            'status': weighted_choice(ENUMS['status'], [0.95, 0.04, 0.01]),
            'created_at': format_timestamp(random_date_in_range(730)),
            'updated_at': format_timestamp(datetime.now()),
        }
        users.append(user)
        
        # Consumer record (will be populated with aggregates later)
        consumer = {
            'id': user_id,
            'birthday': format_date(fake.date_of_birth(minimum_age=18, maximum_age=80)),
            'gender': weighted_choice(ENUMS['gender'], [0.48, 0.48, 0.02, 0.02]),
            'first_order_date': '',
            'total_orders': 0,
            'total_spent': format_decimal(Decimal('0'), 4),
            'customer_segment': 'One-time',
        }
        consumers.append(consumer)
    
    print(f"✅ Created {len(users)} consumer users")
    return users, consumers

def generate_sellers(num_sellers: int) -> Tuple[List[Dict], List[Dict]]:
    """Generate sellers and their user accounts"""
    print(f"🏪 Generating {num_sellers} sellers...")
    users = []
    sellers = []
    
    iterator = range(num_sellers)
    if TQDM_AVAILABLE:
        iterator = tqdm(iterator, desc="Creating sellers", unit="seller")
    
    for i in iterator:
        user_id = generate_uuid()
        
        # User record
        user = {
            'id': user_id,
            'username': 'seller_' + fake.user_name() + str(random.randint(100, 9999)),
            'phone': fake.phone_number()[:15],
            'name': clean_text_field(fake.company()[:100]),
            'email': f"seller{i}@{fake.domain_name()}",
            'status': weighted_choice(ENUMS['status'], [0.95, 0.04, 0.01]),
            'created_at': format_timestamp(random_date_in_range(1095)),
            'updated_at': format_timestamp(datetime.now()),
        }
        users.append(user)
        
        # Seller record
        seller = {
            'id': user_id,
            'type': weighted_choice(ENUMS['seller_type'], [0.85, 0.15]),
            'introduction': clean_text_field(fake.paragraph(nb_sentences=3))[:400],
            'address': clean_text_field(fake.street_address()[:150]),
            'city': clean_text_field(fake.city()[:50]),
            'province': clean_text_field(fake.state()[:50]),
            'country': clean_text_field(fake.country()[:60]),
            'rating_avg': format_rating(Decimal('0')),
            'total_sales': format_decimal(Decimal('0'), 4),
            'total_orders': 0,
        }
        sellers.append(seller)
    
    print(f"✅ Created {len(sellers)} sellers")
    return users, sellers

def generate_address_books(consumers: List[Dict]) -> List[Dict]:
    """Generate shipping addresses for consumers"""
    print("📍 Generating address books...")
    addresses = []
    
    iterator = consumers
    if TQDM_AVAILABLE:
        iterator = tqdm(consumers, desc="Creating addresses", unit="consumer")
    
    for consumer in iterator:
        num_addresses = random.randint(*CONFIG['address_per_consumer_range'])
        
        for i in range(num_addresses):
            address = {
                'id': generate_uuid(),
                'user_id': consumer['id'],
                'address_line_1': clean_text_field(fake.street_address()[:100]),
                'address_line_2': clean_text_field(fake.secondary_address()[:100]) if random.random() > 0.7 else '',
                'city': clean_text_field(fake.city()[:50]),
                'province': clean_text_field(fake.state()[:50]),
                'country': clean_text_field(fake.country()[:30]),
                'postal_code': fake.postcode()[:10],
                'phone': fake.phone_number()[:15],
                'receiver_name': clean_text_field(fake.name()[:100]),
                'is_default': 'true' if i == 0 else 'false',
                'latitude': str(random_decimal(-90, 90, 7)),
                'longitude': str(random_decimal(-180, 180, 7)),
                'created_at': format_timestamp(datetime.now() - timedelta(days=random.randint(0, 365))),
                'updated_at': format_timestamp(datetime.now()),
            }
            addresses.append(address)
    
    print(f"✅ Created {len(addresses)} addresses")
    return addresses

def generate_seller_verticals(sellers: List[Dict], verticals: List[Dict]) -> List[Dict]:
    """Generate seller-vertical relationships"""
    print("🔗 Generating seller-vertical relationships...")
    relationships = []
    
    for seller in sellers:
        # Each seller operates in 1-5 verticals
        num_verticals = random.randint(1, min(5, len(verticals)))
        selected_verticals = random.sample(verticals, num_verticals)
        
        for vertical in selected_verticals:
            rel = {
                'seller_id': seller['id'],
                'vertical_id': vertical['id'],
                'created_at': format_timestamp(datetime.now() - timedelta(days=random.randint(0, 730))),
                'updated_at': format_timestamp(datetime.now()),
            }
            relationships.append(rel)
    
    print(f"✅ Created {len(relationships)} seller-vertical links")
    return relationships

def generate_commodities(sellers: List[Dict], verticals: List[Dict], seller_verticals: List[Dict]) -> List[Dict]:
    """Generate product catalog"""
    print(f"📦 Generating {CONFIG['num_commodities']} commodities...")
    commodities = []
    
    # Build lookup: seller_id -> list of vertical_ids
    seller_to_verticals = defaultdict(list)
    for sv in seller_verticals:
        seller_to_verticals[sv['seller_id']].append(sv['vertical_id'])
    
    # VALIDATION: Ensure all sellers have at least one vertical
    sellers_with_verticals = [s for s in sellers if s['id'] in seller_to_verticals]
    if not sellers_with_verticals:
        print("⚠️  WARNING: No sellers have verticals assigned. Using all sellers with random verticals.")
        sellers_with_verticals = sellers
    
    iterator = range(CONFIG['num_commodities'])
    if TQDM_AVAILABLE:
        iterator = tqdm(iterator, desc="Creating commodities", unit="product")
    
    for i in iterator:
        seller = random.choice(sellers_with_verticals)
        
        # Choose vertical from seller's verticals (STRONG REFERENTIAL INTEGRITY)
        if seller['id'] in seller_to_verticals:
            vertical_id = random.choice(seller_to_verticals[seller['id']])
        else:
            vertical_id = random.choice(verticals)['id']
        
        price = random_decimal(5.0, 2000.0, decimals=4)
        cost_price = price * random_decimal(0.4, 0.8, decimals=4)  # 40-80% of selling price
        
        commodity = {
            'id': generate_uuid(),
            'seller_id': seller['id'],
            'sku': generate_unique_sku(),
            'name': clean_text_field(fake.catch_phrase()[:255]),
            'price': format_decimal(price, 4),
            'cost_price': format_decimal(cost_price, 4),
            'quantity': random.randint(0, 5000),
            'reserved_quantity': 0,
            'reorder_level': random.randint(5, 50),
            'reorder_quantity': random.randint(50, 500),
            'weight_kg': format_decimal(random_decimal(0.1, 50.0, decimals=4), 4),
            'description': clean_text_field(fake.text(max_nb_chars=200)) if random.random() > 0.3 else '',
            'technical_info': clean_text_field(fake.text(max_nb_chars=200)) if random.random() > 0.6 else '',
            'guarantee_info': clean_text_field(fake.text(max_nb_chars=200)) if random.random() > 0.7 else '',
            'manufacturer_name': clean_text_field(fake.company()[:100]) if random.random() > 0.4 else '',
            'vertical_id': vertical_id,
            'status': weighted_choice(ENUMS['commodity_status'], [0.85, 0.08, 0.05, 0.02]),
            'rating_avg': format_rating(Decimal('0')),
            'review_count': 0,
            'total_sold': 0,
            'created_at': format_timestamp(random_date_in_range(730)),
            'updated_at': format_timestamp(datetime.now()),
        }
        commodities.append(commodity)
    
    print(f"✅ Created {len(commodities)} commodities")
    return commodities

def generate_cards(consumers: List[Dict]) -> Tuple[List[Dict], Dict[str, List[Dict]]]:
    """Generate payment cards for consumers"""
    print("💳 Generating credit cards...")
    cards = []
    consumer_cards_map = {}  # Track cards per consumer
    
    iterator = consumers
    if TQDM_AVAILABLE:
        iterator = tqdm(consumers, desc="Creating cards", unit="consumer")
    
    for consumer in iterator:
        num_cards = random.randint(*CONFIG['cards_per_consumer_range'])
        consumer_cards = []
        
        for i in range(num_cards):
            card_number = fake.credit_card_number()
            
            card = {
                'id': generate_uuid(),
                'consumer_id': consumer['id'],
                'tk': hash_card_number(card_number),
                'provider': weighted_choice(ENUMS['card_provider'], [0.40, 0.30, 0.10, 0.05, 0.05, 0.05, 0.05]),
                'last4': card_number[-4:],
                'card_holder': clean_text_field(fake.name()[:100]),
                'exp_year': random.randint(2024, 2030),
                'exp_month': random.randint(1, 12),
                'status': weighted_choice(ENUMS['card_status'], [0.90, 0.05, 0.03, 0.01, 0.01]),
                'is_default': 'true' if i == 0 else 'false',
                'created_at': format_timestamp(random_date_in_range(1095)),
                'updated_at': format_timestamp(datetime.now()),
            }
            cards.append(card)
            consumer_cards.append(card)
        
        consumer_cards_map[consumer['id']] = consumer_cards
    
    print(f"✅ Created {len(cards)} cards")
    return cards, consumer_cards_map

def generate_orders_and_related(
    consumers: List[Dict],
    sellers: List[Dict],
    commodities: List[Dict],
    cards_map: Dict[str, List[Dict]],
    addresses: List[Dict]
) -> Tuple[List[Dict], List[Dict], List[Dict], List[Dict]]:
    """Generate orders, order_commodities, transactions, and reviews"""
    print(f"🛒 Generating {CONFIG['num_orders']} orders with line items...")
    
    orders = []
    order_commodities = []
    transactions = []
    reviews = []
    
    # Build lookups
    consumer_addresses = defaultdict(list)
    for addr in addresses:
        consumer_addresses[addr['user_id']].append(addr)
    
    # Track aggregates for denormalization
    consumer_stats = defaultdict(lambda: {'orders': 0, 'spent': Decimal('0.0000'), 'first_order': None})
    seller_stats = defaultdict(lambda: {'orders': 0, 'sales': Decimal('0.0000'), 'ratings': []})
    commodity_stats = defaultdict(lambda: {'sold': 0, 'ratings': []})
    
    iterator = range(CONFIG['num_orders'])
    if TQDM_AVAILABLE:
        iterator = tqdm(iterator, desc="Creating orders", unit="order")
    
    for i in iterator:
        consumer = random.choice(consumers)
        seller = random.choice(sellers)
        
        # Get consumer's address
        consumer_addrs = consumer_addresses.get(consumer['id'], [])
        if not consumer_addrs:
            continue  # Skip if no address
        
        delivery_addr = random.choice(consumer_addrs)
        
        # Order timestamps
        created_at = random_date_in_range(365)
        order_status = weighted_choice(ENUMS['order_status'], [0.02, 0.05, 0.03, 0.10, 0.55, 0.20, 0.03, 0.02])
        
        # Generate order line items
        num_items = random.randint(*CONFIG['items_per_order_range'])
        selected_commodities = random.sample(commodities, min(num_items, len(commodities)))
        
        subtotal = Decimal('0.0000')
        order_items = []
        
        for commodity in selected_commodities:
            quantity = random.randint(1, 5)
            unit_price = Decimal(commodity['price'])
            unit_cost = Decimal(commodity['cost_price']) if commodity['cost_price'] else unit_price * Decimal('0.6')
            line_total = unit_price * quantity
            unit_cost = quantize_decimal(unit_cost, 4)
            discount = quantize_decimal(random_decimal(0, line_total * Decimal('0.2'), decimals=4), 4)
            net_total = quantize_decimal(line_total - discount, 4)
            
            order_item = {
                'order_id': '',  # Will be filled
                'commodity_id': commodity['id'],
                'quantity': quantity,
                'unit_price': format_decimal(unit_price, 4),
                'unit_cost': format_decimal(unit_cost, 4),
                'line_total': format_decimal(net_total, 4),
                'discount_applied': format_decimal(discount, 4),
            }
            order_items.append(order_item)
            subtotal = quantize_decimal(subtotal + net_total, 4)
        
        # Calculate order totals
        tax_amount = quantize_decimal(subtotal * Decimal('0.08'), 4)  # 8% tax
        shipping_fee = quantize_decimal(random_decimal(0, 20, decimals=4), 4)
        discount_amount = quantize_decimal(random_decimal(0, subtotal * Decimal('0.1'), decimals=4), 4)
        total_amount = quantize_decimal(subtotal + tax_amount + shipping_fee - discount_amount, 4)
        
        # Order record
        order_id = generate_uuid()
        order = {
            'id': order_id,
            'consumer_id': consumer['id'],
            'seller_id': seller['id'],
            'status': order_status,
            'delivery_address': delivery_addr['address_line_1'],
            'delivery_postal_code': delivery_addr['postal_code'],
            'delivery_receiver': delivery_addr['receiver_name'],
            'delivery_phone': delivery_addr['phone'],
            'delivery_city': delivery_addr['city'],
            'delivery_country': delivery_addr['country'],
            'delivery_latitude': delivery_addr['latitude'],
            'delivery_longitude': delivery_addr['longitude'],
            'subtotal_amount': format_decimal(subtotal, 4),
            'tax_amount': format_decimal(tax_amount, 4),
            'shipping_fee': format_decimal(shipping_fee, 4),
            'discount_amount': format_decimal(discount_amount, 4),
            'total_amount': format_decimal(total_amount, 4),
            'created_at': format_timestamp(created_at),
            'confirmed_at': '',
            'paid_at': '',
            'shipped_at': '',
            'delivered_at': '',
            'completed_at': '',
            'updated_at': format_timestamp(datetime.now()),
            'days_to_ship': '',
            'days_to_deliver': '',
        }
        
        # Set timestamps based on status
        if order_status != 'draft':
            order['confirmed_at'] = format_timestamp(created_at + timedelta(hours=random.randint(1, 24)))
        
        if order_status in ['inprogress', 'shipped', 'delivered', 'done']:
            paid_at = created_at + timedelta(hours=random.randint(1, 48))
            order['paid_at'] = format_timestamp(paid_at)
            
            if order_status in ['shipped', 'delivered', 'done']:
                shipped_at = paid_at + timedelta(days=random.randint(1, 5))
                order['shipped_at'] = format_timestamp(shipped_at)
                order['days_to_ship'] = str((shipped_at - paid_at).days)
                
                if order_status in ['delivered', 'done']:
                    delivered_at = shipped_at + timedelta(days=random.randint(1, 7))
                    order['delivered_at'] = format_timestamp(delivered_at)
                    order['days_to_deliver'] = str((delivered_at - shipped_at).days)
                    
                    if order_status == 'done':
                        order['completed_at'] = format_timestamp(delivered_at + timedelta(days=random.randint(7, 14)))
        
        orders.append(order)
        
        # Add order_id to line items
        for item in order_items:
            item['order_id'] = order_id
            order_commodities.append(item)
        
        # Generate transaction
        if order_status in ['inprogress', 'shipped', 'delivered', 'done', 'captured']:
            consumer_cards = cards_map.get(consumer['id'], [])
            if consumer_cards:
                card = random.choice(consumer_cards)
                
                trans_created = created_at + timedelta(hours=random.randint(0, 2))
                trans_status = 'captured' if order_status in ['inprogress', 'shipped', 'delivered', 'done'] else weighted_choice(ENUMS['trans_status'], [0.05, 0.10, 0.80, 0.03, 0.01, 0.01])
                
                transaction = {
                    'id': generate_uuid(),
                    'order_id': order_id,
                    'card_id': card['id'],
                    'payment_method': 'card',
                    'transaction_type': 'sale',
                    'amount': format_decimal(total_amount, 4),
                    'status': trans_status,
                    'created_at': format_timestamp(trans_created),
                    'authorized_at': format_timestamp(trans_created + timedelta(seconds=random.randint(1, 60))) if trans_status != 'draft' else '',
                    'completed_at': format_timestamp(trans_created + timedelta(seconds=random.randint(60, 300))) if trans_status == 'captured' else '',
                    'gateway_transaction_id': f"GTW-{random.randint(100000000, 999999999)}",
                    'gateway_response_code': '00' if trans_status == 'captured' else str(random.randint(1, 99)).zfill(2),
                    'gateway_response_message': 'Approved' if trans_status == 'captured' else 'Declined',
                    'ip_address': fake.ipv4(),
                    'user_agent': clean_text_field(fake.user_agent()[:255]),
                }
                transactions.append(transaction)
        
        # Generate review (30% chance for delivered/done orders)
        if order_status in ['delivered', 'done'] and random.random() < 0.3:
            for item in order_items:
                if random.random() < 0.5:  # 50% of items get reviewed
                    rate = weighted_choice([1, 2, 3, 4, 5], [0.05, 0.05, 0.15, 0.35, 0.40])
                    
                    review = {
                        'id': generate_uuid(),
                        'order_id': order_id,
                        'commodity_id': item['commodity_id'],
                        'consumer_id': consumer['id'],
                        'seller_id': seller['id'],
                        'rate': rate,
                        'comment': clean_text_field(fake.text(max_nb_chars=500)) if random.random() > 0.2 else '',
                        'status': weighted_choice(ENUMS['review_status'], [0.05, 0.90, 0.03, 0.02]),
                        'is_verified_purchase': 'true',
                        'helpful_count': random.randint(0, 100),
                        'created_at': format_timestamp(datetime.strptime(order['delivered_at'], '%Y-%m-%d %H:%M:%S') + timedelta(days=random.randint(1, 30))),
                        'updated_at': format_timestamp(datetime.now()),
                        'published_at': format_timestamp(datetime.strptime(order['delivered_at'], '%Y-%m-%d %H:%M:%S') + timedelta(days=random.randint(1, 31))),
                    }
                    reviews.append(review)
                    
                    # Track for aggregation
                    commodity_stats[item['commodity_id']]['ratings'].append(rate)
                    seller_stats[seller['id']]['ratings'].append(rate)
        
        # Track aggregates for completed orders
        if order_status in ['delivered', 'done']:
            consumer_stats[consumer['id']]['orders'] += 1
            consumer_stats[consumer['id']]['spent'] += total_amount
            if consumer_stats[consumer['id']]['first_order'] is None:
                consumer_stats[consumer['id']]['first_order'] = created_at
            
            seller_stats[seller['id']]['orders'] += 1
            seller_stats[seller['id']]['sales'] += total_amount
            
            for item in order_items:
                commodity_stats[item['commodity_id']]['sold'] += item['quantity']
    
    print(f"✅ Created {len(orders)} orders")
    print(f"✅ Created {len(order_commodities)} order line items")
    print(f"✅ Created {len(transactions)} transactions")
    print(f"✅ Created {len(reviews)} reviews")
    
    # Update denormalized fields
    print("📊 Updating denormalized aggregates...")
    
    for consumer in consumers:
        stats = consumer_stats[consumer['id']]
        consumer['total_orders'] = stats['orders']
        consumer['total_spent'] = format_decimal(stats['spent'], 4)
        consumer['customer_segment'] = calculate_customer_segment(stats['spent'])
        if stats['first_order']:
            consumer['first_order_date'] = format_date(stats['first_order'])
    
    for seller in sellers:
        stats = seller_stats[seller['id']]
        seller['total_orders'] = stats['orders']
        seller['total_sales'] = format_decimal(stats['sales'], 4)
        if stats['ratings']:
            avg_rating = Decimal(sum(stats['ratings'])) / Decimal(len(stats['ratings']))
            seller['rating_avg'] = format_rating(avg_rating)
        else:
            seller['rating_avg'] = format_rating(Decimal('0'))
    
    for commodity in commodities:
        stats = commodity_stats[commodity['id']]
        commodity['total_sold'] = stats['sold']
        commodity['review_count'] = len(stats['ratings'])
        if stats['ratings']:
            avg_rating = Decimal(sum(stats['ratings'])) / Decimal(len(stats['ratings']))
            commodity['rating_avg'] = format_rating(avg_rating)
        else:
            commodity['rating_avg'] = format_rating(Decimal('0'))
    
    return orders, order_commodities, transactions, reviews

# ============================================================================
# CSV EXPORT
# ============================================================================

def export_to_csv(filename: str, data: List[Dict], fieldnames: List[str]):
    """Export data to CSV file with Unix line endings (required for Redshift)"""
    output_path = os.path.join(CONFIG['output_dir'], filename)
    
    # Force Unix line endings (\n) for Redshift compatibility
    with open(output_path, 'w', newline='\n', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=CONFIG['delimiter'], 
                               extrasaction='ignore', lineterminator='\n')
        writer.writeheader()
        writer.writerows(data)
    
    print(f"📁 Exported {len(data)} rows to {filename}")

def export_all_data(users, consumers, sellers, verticals, seller_verticals, address_books, 
                    commodities, cards, orders, order_commodities, transactions, reviews):
    """Export all data to CSV files"""
    print("\n" + "=" * 60)
    print("💾 EXPORTING DATA TO CSV FILES")
    print("=" * 60)
    
    # Create output directory
    os.makedirs(CONFIG['output_dir'], exist_ok=True)
    
    # Define fieldnames for each table
    exports = [
        ('users.csv', users, ['id', 'username', 'phone', 'name', 'email', 'status', 'created_at', 'updated_at']),
        ('consumers.csv', consumers, ['id', 'birthday', 'gender', 'first_order_date', 'total_orders', 'total_spent', 'customer_segment']),
        ('sellers.csv', sellers, ['id', 'type', 'introduction', 'address', 'city', 'province', 'country', 'rating_avg', 'total_sales', 'total_orders']),
        ('verticals.csv', verticals, ['id', 'name', 'description', 'status']),
        ('seller_vertical.csv', seller_verticals, ['seller_id', 'vertical_id', 'created_at', 'updated_at']),
        ('address_books.csv', address_books, ['id', 'user_id', 'address_line_1', 'address_line_2', 'city', 'province', 'country', 'postal_code', 'phone', 'receiver_name', 'is_default', 'latitude', 'longitude', 'created_at', 'updated_at']),
        ('commodities.csv', commodities, ['id', 'seller_id', 'sku', 'name', 'price', 'cost_price', 'quantity', 'reserved_quantity', 'reorder_level', 'reorder_quantity', 'weight_kg', 'description', 'technical_info', 'guarantee_info', 'manufacturer_name', 'vertical_id', 'status', 'rating_avg', 'review_count', 'total_sold', 'created_at', 'updated_at']),
        ('cards.csv', cards, ['id', 'consumer_id', 'tk', 'provider', 'last4', 'card_holder', 'exp_year', 'exp_month', 'status', 'is_default', 'created_at', 'updated_at']),
        ('orders.csv', orders, ['id', 'consumer_id', 'seller_id', 'status', 'delivery_address', 'delivery_postal_code', 'delivery_receiver', 'delivery_phone', 'delivery_city', 'delivery_country', 'delivery_latitude', 'delivery_longitude', 'subtotal_amount', 'tax_amount', 'shipping_fee', 'discount_amount', 'total_amount', 'created_at', 'confirmed_at', 'paid_at', 'shipped_at', 'delivered_at', 'completed_at', 'updated_at', 'days_to_ship', 'days_to_deliver']),
        ('order_commodities.csv', order_commodities, ['order_id', 'commodity_id', 'quantity', 'unit_price', 'unit_cost', 'line_total', 'discount_applied']),
        ('transactions.csv', transactions, ['id', 'order_id', 'card_id', 'payment_method', 'transaction_type', 'amount', 'status', 'created_at', 'authorized_at', 'completed_at', 'gateway_transaction_id', 'gateway_response_code', 'gateway_response_message', 'ip_address', 'user_agent']),
        ('reviews.csv', reviews, ['id', 'order_id', 'commodity_id', 'consumer_id', 'seller_id', 'rate', 'comment', 'status', 'is_verified_purchase', 'helpful_count', 'created_at', 'updated_at', 'published_at']),
    ]
    
    for filename, data, fieldnames in exports:
        export_to_csv(filename, data, fieldnames)
    
    print(f"\n✅ All data exported to '{CONFIG['output_dir']}' directory")

# ============================================================================
# POSTGRESQL INSERTION
# ============================================================================

def get_postgres_connection():
    """Connect to PostgreSQL"""
    if not PSYCOPG2_AVAILABLE:
        print("❌ PostgreSQL insertion skipped - psycopg2 not available")
        return None
    
    try:
        conn = psycopg2.connect(**CONFIG['postgres'])
        print(f"✅ Connected to PostgreSQL: {CONFIG['postgres']['database']}")
        return conn
    except Exception as e:
        print(f"❌ PostgreSQL connection failed: {e}")
        return None

def insert_into_table(table_name: str, data: List[Dict]):
    """Insert data into PostgreSQL table"""
    if not data:
        print(f"⚠️  Skipping {table_name} - no data")
        return
    
    conn = get_postgres_connection()
    if not conn:
        return
    
    try:
        cur = conn.cursor()
        
        # Get column names from first record
        columns = list(data[0].keys())
        placeholders = ', '.join(['%s'] * len(columns))
        insert_query = f"INSERT INTO {table_name} ({', '.join(columns)}) VALUES ({placeholders})"
        
        # Prepare data
        values = [[record.get(col, None) or None for col in columns] for record in data]
        
        # Batch insert
        execute_batch(cur, insert_query, values, page_size=1000)
        conn.commit()
        
        print(f"✅ Inserted {len(data)} rows into {table_name}")
        
        cur.close()
        conn.close()
    
    except Exception as e:
        print(f"❌ Error inserting into {table_name}: {e}")
        if conn:
            conn.rollback()
            conn.close()

# ============================================================================
# MAIN EXECUTION
# ============================================================================

def main():
    """Main execution flow"""
    print("=" * 60)
    print("🚀 E-COMMERCE DATA GENERATOR")
    print("=" * 60)
    print(f"Output directory: {CONFIG['output_dir']}")
    print(f"Delimiter: '{CONFIG['delimiter']}'")
    print(f"Consumers: {CONFIG['num_consumers']}")
    print(f"Sellers: {CONFIG['num_sellers']}")
    print(f"Commodities: {CONFIG['num_commodities']}")
    print(f"Orders: {CONFIG['num_orders']}")
    print("=" * 60)
    
    # Step 1: Generate verticals (persistent)
    verticals = load_or_generate_verticals()
    
    # Step 2: Generate users and profiles
    consumer_users, consumers = generate_users_and_consumers()
    seller_users, sellers = generate_sellers(CONFIG['num_sellers'])
    all_users = consumer_users + seller_users
    
    # Step 3: Generate related data
    seller_verticals = generate_seller_verticals(sellers, verticals)
    address_books = generate_address_books(consumers)
    commodities = generate_commodities(sellers, verticals, seller_verticals)
    cards, cards_map = generate_cards(consumers)
    
    # Step 4: Generate orders and related data
    orders, order_commodities, transactions, reviews = generate_orders_and_related(
        consumers, sellers, commodities, cards_map, address_books
    )
    
    # Step 5: Export to CSV
    export_all_data(all_users, consumers, sellers, verticals, seller_verticals, address_books,
                    commodities, cards, orders, order_commodities, transactions, reviews)
    
    # Step 6: Insert into PostgreSQL
    # IMPORTANT: Follow correct dependency order for foreign keys
    print("=" * 60)
    print("🔄 INSERTING DATA INTO POSTGRESQL...")
    print("=" * 60)
    
    # 1. Base table (no dependencies)
    insert_into_table('users', all_users)
    
    # 2. User role tables (depend on users)
    insert_into_table('consumers', consumers)
    insert_into_table('sellers', sellers)
    
    # 3. Verticals (no dependencies except self-reference)
    insert_into_table('verticals', verticals)
    
    # 4. Tables depending on consumers, sellers, verticals
    insert_into_table('seller_vertical', seller_verticals)
    insert_into_table('address_books', address_books)
    insert_into_table('cards', cards)
    
    # 5. Commodities (depends on sellers and verticals)
    insert_into_table('commodities', commodities)
    
    # 6. Orders (depends on consumers and sellers)
    insert_into_table('orders', orders)
    
    # 7. Tables depending on orders
    insert_into_table('order_commodities', order_commodities)
    insert_into_table('transactions', transactions)
    insert_into_table('reviews', reviews)
    
    # Summary
    print("\n" + "=" * 60)
    print("🎉 DATA GENERATION COMPLETED!")
    print("=" * 60)
    print(f"📁 CSV files: {CONFIG['output_dir']}/")
    print(f"📊 Total records generated:")
    print(f"   - Users: {len(all_users)}")
    print(f"   - Consumers: {len(consumers)}")
    print(f"   - Sellers: {len(sellers)}")
    print(f"   - Verticals: {len(verticals)}")
    print(f"   - Seller-Verticals: {len(seller_verticals)}")
    print(f"   - Address Books: {len(address_books)}")
    print(f"   - Commodities: {len(commodities)}")
    print(f"   - Cards: {len(cards)}")
    print(f"   - Orders: {len(orders)}")
    print(f"   - Order Items: {len(order_commodities)}")
    print(f"   - Transactions: {len(transactions)}")
    print(f"   - Reviews: {len(reviews)}")
    print("=" * 60)

if __name__ == '__main__':
    main()
