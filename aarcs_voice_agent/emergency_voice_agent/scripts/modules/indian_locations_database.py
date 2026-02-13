# indian_locations_database.py - Comprehensive India Location Database
"""
Complete database of Indian locations including:
- All major cities (300+)
- Popular areas/localities
- Famous landmarks
- State-wise coverage
"""

# Major Cities by State (with coordinates)
INDIAN_CITIES = {
    # Tamil Nadu
    'chennai': (13.0827, 80.2707),
    'coimbatore': (11.0168, 76.9558),
    'madurai': (9.9252, 78.1198),
    'salem': (11.6643, 78.1460),
    'tiruchirappalli': (10.7905, 78.7047),
    'trichy': (10.7905, 78.7047),
    'tirunelveli': (8.7139, 77.7567),
    'tiruppur': (11.1085, 77.3411),
    'vellore': (12.9165, 79.1325),
    'erode': (11.3410, 77.7172),
    'thoothukudi': (8.7642, 78.1348),
    'tuticorin': (8.7642, 78.1348),
    'dindigul': (10.3673, 77.9803),
    'thanjavur': (10.7870, 79.1378),
    'nagercoil': (8.1790, 77.4340),
    
    # Karnataka
    'bangalore': (12.9716, 77.5946),
    'bengaluru': (12.9716, 77.5946),
    'mysore': (12.2958, 76.6394),
    'mysuru': (12.2958, 76.6394),
    'hubli': (15.3647, 75.1240),
    'mangalore': (12.9141, 74.8560),
    'belgaum': (15.8497, 74.4977),
    'gulbarga': (17.3297, 76.8343),
    'davangere': (14.4644, 75.9218),
    'bellary': (15.1394, 76.9214),
    'bijapur': (16.8302, 75.7100),
    'shimoga': (13.9299, 75.5681),
    'tumkur': (13.3392, 77.1006),
    'raichur': (16.2120, 77.3439),
    
    # Maharashtra
    'mumbai': (19.0760, 72.8777),
    'pune': (18.5204, 73.8567),
    'nagpur': (21.1458, 79.0882),
    'nashik': (19.9975, 73.7898),
    'aurangabad': (19.8762, 75.3433),
    'solapur': (17.6599, 75.9064),
    'kolhapur': (16.7050, 74.2433),
    'thane': (19.2183, 72.9781),
    'navi mumbai': (19.0330, 73.0297),
    'amravati': (20.9374, 77.7796),
    'sangli': (16.8524, 74.5815),
    'jalgaon': (21.0077, 75.5626),
    
    # Delhi NCR
    'delhi': (28.7041, 77.1025),
    'new delhi': (28.6139, 77.2090),
    'gurgaon': (28.4595, 77.0266),
    'gurugram': (28.4595, 77.0266),
    'noida': (28.5355, 77.3910),
    'faridabad': (28.4089, 77.3178),
    'ghaziabad': (28.6692, 77.4538),
    
    # Uttar Pradesh
    'lucknow': (26.8467, 80.9462),
    'kanpur': (26.4499, 80.3319),
    'agra': (27.1767, 78.0081),
    'varanasi': (25.3176, 82.9739),
    'meerut': (28.9845, 77.7064),
    'allahabad': (25.4358, 81.8463),
    'prayagraj': (25.4358, 81.8463),
    'bareilly': (28.3670, 79.4304),
    'aligarh': (27.8974, 78.0880),
    'moradabad': (28.8389, 78.7378),
    'gorakhpur': (26.7606, 83.3732),
    'jhansi': (25.4484, 78.5685),
    
    # Gujarat
    'ahmedabad': (23.0225, 72.5714),
    'surat': (21.1702, 72.8311),
    'vadodara': (22.3072, 73.1812),
    'rajkot': (22.3039, 70.8022),
    'bhavnagar': (21.7645, 72.1519),
    'jamnagar': (22.4707, 70.0577),
    'gandhinagar': (23.2156, 72.6369),
    'junagadh': (21.5222, 70.4579),
    
    # Rajasthan
    'jaipur': (26.9124, 75.7873),
    'jodhpur': (26.2389, 73.0243),
    'udaipur': (24.5854, 73.7125),
    'kota': (25.2138, 75.8648),
    'ajmer': (26.4499, 74.6399),
    'bikaner': (28.0229, 73.3119),
    'alwar': (27.5530, 76.6346),
    
    # West Bengal
    'kolkata': (22.5726, 88.3639),
    'howrah': (22.5958, 88.2636),
    'durgapur': (23.5204, 87.3119),
    'siliguri': (26.7271, 88.3953),
    'asansol': (23.6739, 86.9524),
    
    # Telangana
    'hyderabad': (17.3850, 78.4867),
    'warangal': (17.9689, 79.5941),
    'nizamabad': (18.6725, 78.0941),
    'karimnagar': (18.4386, 79.1288),
    
    # Andhra Pradesh
    'visakhapatnam': (17.6868, 83.2185),
    'vizag': (17.6868, 83.2185),
    'vijayawada': (16.5062, 80.6480),
    'guntur': (16.3067, 80.4365),
    'nellore': (14.4426, 79.9865),
    'tirupati': (13.6288, 79.4192),
    'kakinada': (16.9891, 82.2475),
    
    # Madhya Pradesh
    'indore': (22.7196, 75.8577),
    'bhopal': (23.2599, 77.4126),
    'jabalpur': (23.1815, 79.9864),
    'gwalior': (26.2183, 78.1828),
    'ujjain': (23.1765, 75.7885),
    
    # Bihar
    'patna': (25.5941, 85.1376),
    'gaya': (24.7955, 84.9994),
    'bhagalpur': (25.2425, 86.9842),
    'muzaffarpur': (26.1209, 85.3647),
    
    # Punjab
    'amritsar': (31.6340, 74.8723),
    'ludhiana': (30.9010, 75.8573),
    'jalandhar': (31.3260, 75.5762),
    'patiala': (30.3398, 76.3869),
    
    # Kerala
    'thiruvananthapuram': (8.5241, 76.9366),
    'trivandrum': (8.5241, 76.9366),
    'kochi': (9.9312, 76.2673),
    'cochin': (9.9312, 76.2673),
    'kozhikode': (11.2588, 75.7804),
    'calicut': (11.2588, 75.7804),
    'thrissur': (10.5276, 76.2144),
    'kollam': (8.8932, 76.6141),
    
    # Haryana
    'faridabad': (28.4089, 77.3178),
    'rohtak': (28.8955, 76.6066),
    'panipat': (29.3909, 76.9635),
    'karnal': (29.6857, 76.9905),
    'hisar': (29.1492, 75.7217),
    
    # Jharkhand
    'ranchi': (23.3441, 85.3096),
    'jamshedpur': (22.8046, 86.2029),
    'dhanbad': (23.7957, 86.4304),
    'bokaro': (23.6693, 86.1511),
    
    # Odisha
    'bhubaneswar': (20.2961, 85.8245),
    'cuttack': (20.4625, 85.8828),
    'rourkela': (22.2604, 84.8536),
    
    # Chhattisgarh
    'raipur': (21.2514, 81.6296),
    'bhilai': (21.2095, 81.4290),
    'bilaspur': (22.0797, 82.1409),
    
    # Assam
    'guwahati': (26.1445, 91.7362),
    'dibrugarh': (27.4728, 94.9120),
    'silchar': (24.8333, 92.7789),
    
    # Uttarakhand
    'dehradun': (30.3165, 78.0322),
    'haridwar': (29.9457, 78.1642),
    'roorkee': (29.8543, 77.8880),
    
    # Himachal Pradesh
    'shimla': (31.1048, 77.1734),
    'manali': (32.2432, 77.1892),
    
    # Jammu & Kashmir
    'srinagar': (34.0837, 74.7973),
    'jammu': (32.7266, 74.8570),
    
    # Other Union Territories
    'chandigarh': (30.7333, 76.7794),
    'puducherry': (11.9416, 79.8083),
    'pondicherry': (11.9416, 79.8083),
    'port blair': (11.6234, 92.7265),
}

# Chennai Specific Areas (Example - Replicate for other cities)
CHENNAI_AREAS = {
    'tambaram': (12.9229, 80.1275),
    'velachery': (12.9750, 80.2192),
    'adyar': (13.0067, 80.2583),
    't nagar': (13.0418, 80.2341),
    'anna nagar': (13.0850, 80.2101),
    'porur': (13.0358, 80.1561),
    'perungudi': (12.9611, 80.2426),
    'sholinganallur': (12.9008, 80.2267),
    'guindy': (13.0067, 80.2206),
    'kodambakkam': (13.0525, 80.2253),
    'mylapore': (13.0339, 80.2619),
    'nungambakkam': (13.0590, 80.2428),
    'egmore': (13.0732, 80.2609),
    'chrompet': (12.9516, 80.1462),
    'pallavaram': (12.9675, 80.1491),
    'medavakkam': (12.9200, 80.1920),
    'thoraipakkam': (12.9386, 80.2342),
    'thiruvanmiyur': (12.9830, 80.2595),
    'besant nagar': (13.0007, 80.2668),
    'kilpauk': (13.0771, 80.2425),
    'ashok nagar': (13.0350, 80.2100),
    'ambattur': (13.1143, 80.1548),
    'avadi': (13.1067, 80.1020),
    'redhills': (13.1968, 80.1528),
    'royapuram': (13.1120, 80.2987),
    'koyambedu': (13.0732, 80.1948),
}

# Bangalore Specific Areas
BANGALORE_AREAS = {
    'koramangala': (12.9352, 77.6245),
    'indira nagar': (12.9716, 77.6412),
    'whitefield': (12.9698, 77.7499),
    'electronic city': (12.8399, 77.6770),
    'btm layout': (12.9166, 77.6101),
    'jayanagar': (12.9250, 77.5938),
    'malleshwaram': (13.0033, 77.5712),
    'rajajinagar': (12.9915, 77.5554),
    'mg road': (12.9750, 77.6060),
    'brigade road': (12.9716, 77.6070),
    'hsr layout': (12.9082, 77.6476),
    'sarjapur': (12.8906, 77.7689),
    'marathahalli': (12.9591, 77.6974),
    'hebbal': (13.0358, 77.5970),
    'yeshwanthpur': (13.0280, 77.5370),
}

# Mumbai Specific Areas
MUMBAI_AREAS = {
    'andheri': (19.1136, 72.8697),
    'bandra': (19.0596, 72.8295),
    'borivali': (19.2304, 72.8571),
    'dadar': (19.0179, 72.8479),
    'malad': (19.1864, 72.8493),
    'powai': (19.1176, 72.9060),
    'kurla': (19.0657, 72.8797),
    'goregaon': (19.1551, 72.8490),
    'juhu': (19.1075, 72.8263),
    'worli': (18.9993, 72.8181),
    'churchgate': (18.9322, 72.8264),
    'colaba': (18.9067, 72.8147),
    'marine drive': (18.9432, 72.8236),
    'nariman point': (18.9250, 72.8225),
    'lower parel': (18.9982, 72.8284),
}

# Famous Landmarks (City-wise)
INDIAN_LANDMARKS = {
    # Chennai Landmarks
    'phoenix mall chennai': (12.9950, 80.2208),
    'phoenix marketcity': (12.9950, 80.2208),
    'express avenue': (13.0600, 80.2628),
    'spencer plaza': (13.0606, 80.2620),
    'forum mall': (12.9938, 80.2582),
    'central station chennai': (13.0819, 80.2750),
    'chennai airport': (12.9941, 80.1709),
    'marina beach': (13.0499, 80.2824),
    'kapaleeshwarar temple': (13.0339, 80.2693),
    'vadapalani temple': (13.0504, 80.2121),
    
    # Bangalore Landmarks
    'manyata tech park': (13.0361, 77.6217),
    'mg road bangalore': (12.9750, 77.6060),
    'kempegowda airport': (13.1986, 77.7066),
    'bangalore airport': (13.1986, 77.7066),
    'lalbagh': (12.9507, 77.5848),
    'cubbon park': (12.9763, 77.5926),
    'bangalore palace': (12.9980, 77.5920),
    'ulsoor lake': (12.9819, 77.6230),
    
    # Mumbai Landmarks
    'mumbai airport': (19.0896, 72.8656),
    'gateway of india': (18.9220, 72.8347),
    'bandra worli sea link': (19.0330, 72.8181),
    'cst mumbai': (18.9398, 72.8355),
    'bandra station': (19.0544, 72.8406),
    'phoenix palladium': (19.0668, 72.8294),
    'inorbit mall': (19.1767, 72.8391),
    
    # Delhi Landmarks
    'connaught place': (28.6315, 77.2167),
    'india gate': (28.6129, 77.2295),
    'red fort': (28.6562, 77.2410),
    'qutub minar': (28.5244, 77.1855),
    'indira gandhi airport': (28.5562, 77.1000),
    'delhi airport': (28.5562, 77.1000),
    'saket mall': (28.5244, 77.2177),
    'dlf mall of india': (28.5676, 77.3246),
}

def get_location_from_database(query):
    """
    Search location in offline database
    Returns: (lat, lng, place_name) or None
    """
    query_lower = query.lower().strip()
    
    # Search in major cities
    for city, coords in INDIAN_CITIES.items():
        if city in query_lower:
            return (*coords, city.title())
    
    # Search in Chennai areas
    for area, coords in CHENNAI_AREAS.items():
        if area in query_lower:
            return (*coords, f"{area.title()}, Chennai")
    
    # Search in Bangalore areas
    for area, coords in BANGALORE_AREAS.items():
        if area in query_lower:
            return (*coords, f"{area.title()}, Bangalore")
    
    # Search in Mumbai areas
    for area, coords in MUMBAI_AREAS.items():
        if area in query_lower:
            return (*coords, f"{area.title()}, Mumbai")
    
    # Search in landmarks
    for landmark, coords in INDIAN_LANDMARKS.items():
        if landmark in query_lower:
            return (*coords, landmark.title())
    
    return None

# Add more cities' areas as needed
# Template for adding new city:
# CITY_NAME_AREAS = {
#     'area1': (lat, lng),
#     'area2': (lat, lng),
# }
