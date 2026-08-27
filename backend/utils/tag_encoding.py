"""
Double-Hex (Base-32) Encoding for Pole Tags
Negros Power Standard - 32 Characters
"""

from datetime import datetime
from typing import List, Dict

# ============================================================
# CONSTANTS
# ============================================================

# Your 32-character set (0-9, A-Y excluding I, O, X)
BASE32_CHARS = "0123456789ABCDEFGHJKLMNPQRSTUVWY"
BASE = len(BASE32_CHARS)  # 32

# Total combinations with 4 digits
TOTAL_COMBINATIONS = 32 ** 4  # 1,048,576
MAX_VALUE = TOTAL_COMBINATIONS - 1  # 1,048,575


# ============================================================
# CORE ENCODING FUNCTIONS
# ============================================================

def encode_pole_number(pole_number: int) -> str:
    """
    Convert a decimal pole number to a 4-character Base-32 tag.
    
    Args:
        pole_number: Integer pole number (0 to 1,048,575)
    
    Returns:
        4-character tag code
    
    Examples:
        >>> encode_pole_number(100000)
        '31M0'
        >>> encode_pole_number(1000300)
        'WGJ0'
    """
    if pole_number < 0 or pole_number > MAX_VALUE:
        raise ValueError(
            f"Pole number must be between 0 and {MAX_VALUE:,}"
        )
    
    chars = BASE32_CHARS
    return (
        chars[(pole_number >> 15) & 31] +   # Bit 15-19
        chars[(pole_number >> 10) & 31] +   # Bit 10-14
        chars[(pole_number >> 5) & 31] +    # Bit 5-9
        chars[pole_number & 31]             # Bit 0-4
    )


def decode_tag_code(tag_code: str) -> int:
    """
    Convert a Base-32 tag code back to a decimal pole number.
    
    Args:
        tag_code: 4-character tag code (without DU prefix)
    
    Returns:
        Integer pole number
    
    Examples:
        >>> decode_tag_code("31M0")
        100000
    """
    tag_code = tag_code.upper().strip()
    
    if len(tag_code) != 4:
        raise ValueError(f"Tag code must be exactly 4 characters: {tag_code}")
    
    result = 0
    for char in tag_code:
        if char not in BASE32_CHARS:
            raise ValueError(f"Invalid character '{char}' in tag code")
        result = result * 32 + BASE32_CHARS.index(char)
    
    return result


# ============================================================
# TAG GENERATION (WITH DU PREFIX)
# ============================================================

def generate_all_tags_for_du(du_id: int, du_code: str) -> List[Dict]:
    """
    Generate ALL 1,048,575 tags for a DU with DU code as prefix.
    
    Args:
        du_id: DU ID to associate tags with
        du_code: DU code prefix (e.g., "N", "B", etc.)
    
    Returns:
        List of 1,048,575 tag dictionaries ready for bulk insert
    
    Examples:
        >>> generate_all_tags_for_du(1, "N")
        [
            {'du_id': 1, 'tag_code': 'N0000', 'pole_no': '1', 'status': 'Available'},
            {'du_id': 1, 'tag_code': 'N0001', 'pole_no': '2', 'status': 'Available'},
            ...
        ]
    """
    tags = []
    pole_no = 1
    
    print(f"🔨 Generating {TOTAL_COMBINATIONS:,} tags for DU {du_id} with prefix '{du_code}'...")
    
    # Loop through ALL 1,048,575 combinations
    for num in range(TOTAL_COMBINATIONS):
        # Generate the 4-character Base-32 code
        base32_code = encode_pole_number(num)
        
        # Add the DU code as prefix
        full_tag_code = f"{du_code}{base32_code}"
        
        tags.append({
            'du_id': du_id,
            'tag_code': full_tag_code,
            'pole_no': str(pole_no),
            'status': 'Available',
            'remarks': None,
            'created_at': datetime.utcnow(),
        })
        pole_no += 1
        
        # Progress indicator
        if len(tags) % 100000 == 0:
            print(f"   Generated {len(tags):,} tags...")
    
    print(f"✅ Generated {len(tags):,} tags for DU {du_id}")
    return tags


def generate_tags_batch(du_id: int, du_code: str, start_pole: int, count: int) -> List[Dict]:
    """
    Generate a batch of tags for a DU.
    
    Args:
        du_id: DU ID
        du_code: DU code prefix
        start_pole: Starting pole number
        count: Number of tags to generate
    
    Returns:
        List of tag dictionaries
    """
    tags = []
    pole_num = start_pole
    generated = 0
    
    while generated < count:
        base32_code = encode_pole_number(pole_num)
        full_tag_code = f"{du_code}{base32_code}"
        
        tags.append({
            'du_id': du_id,
            'tag_code': full_tag_code,
            'pole_no': str(start_pole + generated),
            'status': 'Available',
            'created_at': datetime.utcnow(),
        })
        generated += 1
        pole_num += 1
    
    return tags


def format_full_tag(du_code: str, tag_code: str) -> str:
    """
    Format a full tag.
    
    Args:
        du_code: DU code (e.g., "N")
        tag_code: 4-character tag code (e.g., "31M0")
    
    Returns:
        Full tag (e.g., "N31M0")
    """
    return f"{du_code}{tag_code}"


# ============================================================
# TESTING
# ============================================================

if __name__ == "__main__":
    # Test encoding
    print("=== ENCODING TESTS ===")
    print(f"100,000 → {encode_pole_number(100000)}")
    print(f"1,000,300 → {encode_pole_number(1000300)}")
    print(f"0 → {encode_pole_number(0)}")
    print(f"1,048,575 → {encode_pole_number(1048575)}")
    
    # Test decoding
    print("\n=== DECODING TESTS ===")
    print(f"'31M0' → {decode_tag_code('31M0')}")
    print(f"'WGJ0' → {decode_tag_code('WGJ0')}")
    
    # Test tag generation with prefix
    print("\n=== TAG GENERATION WITH PREFIX ===")
    sample_tags = generate_all_tags_for_du(1, "N")[:5]
    for tag in sample_tags:
        print(f"  {tag['tag_code']} → pole {tag['pole_no']}")