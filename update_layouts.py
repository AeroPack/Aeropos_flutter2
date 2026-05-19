import re
import os

# Path to templates directory1
templates_dir = "/home/dell/flutter_app/main/ezo/lib/features/sales/templates"

# List of layout files to update (excluding thermal and modern which are already done)
layouts = ["classic_layout.dart", "luxury_layout.dart", "stylish_layout.dart", 
           "simple_layout.dart", "advanced_gst_layout.dart", "dreams_layout.dart", "custom_layout.dart"]

for layout_file in layouts:
    file_path = os.path.join(templates_dir, layout_file)
    
    if not os.path.exists(file_path):
        print(f"Skipping {layout_file} - file not found")
        continue
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Add profile parameter to generate method signature
    content = re.sub(
        r'(static Future<pw\.Document> generate\(\s*Invoice invoice,\s*CustomerEntity\? customer,\s*InvoiceTemplate template,)\s*\)',
        r'\1\n    Map<String, dynamic>? profile,\n  )',
        content
    )
    
    # Replace template.name with profile data
    content = re.sub(
        r'template\.name',
        r"(profile?['businessName'] ?? profile?['companyName'] ?? 'Business')",
        content
    )
    
    # Replace template.businessAddress with profile data
    content = re.sub(
        r'template\.businessAddress',
        r"profile?['businessAddress']",
        content
    )
    
    # Replace template.businessPhone with profile data
    content = re.sub(
        r'template\.businessPhone',
        r"profile?['phone']",
        content
    )
    
    # Replace template.businessGstin with profile data
    content = re.sub(
        r'template\.businessGstin',
        r"profile?['taxId']",
        content
    )
    
    with open(file_path, 'w') as f:
        f.write(content)
    
    print(f"Updated {layout_file}")

print("All layouts updated!")
