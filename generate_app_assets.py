"""
Generate App Icon and Splash Screen for Audio Classifier App
Medical/Audio theme with brain wave and microphone
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon(size=1024):
    """Create main app icon with medical theme"""
    # Create image with gradient background
    img = Image.new('RGB', (size, size), '#6366F1')
    draw = ImageDraw.Draw(img)
    
    # Draw gradient effect
    for i in range(size):
        color_value = int(99 + (153 - 99) * (i / size))
        draw.line([(0, i), (size, i)], fill=(99, 102, color_value))
    
    # Icon parameters
    center = size // 2
    mic_radius = size // 4
    
    # Draw microphone body (white)
    mic_top = center - mic_radius
    mic_bottom = center + mic_radius // 3
    mic_width = mic_radius
    
    # Microphone capsule (rounded rectangle)
    draw.rounded_rectangle(
        [center - mic_width//2, mic_top, center + mic_width//2, mic_bottom],
        radius=mic_width//2,
        fill='white',
        outline='white',
        width=size//50
    )
    
    # Microphone grid lines (detail)
    grid_spacing = mic_width // 5
    for i in range(3):
        y = mic_top + mic_radius // 3 + i * grid_spacing
        draw.line(
            [(center - mic_width//3, y), (center + mic_width//3, y)],
            fill='#6366F1',
            width=size//100
        )
    
    # Microphone stand
    stand_height = mic_radius // 2
    draw.line(
        [(center, mic_bottom), (center, mic_bottom + stand_height)],
        fill='white',
        width=size//30
    )
    
    # Microphone base (arc)
    base_width = mic_radius
    draw.arc(
        [center - base_width//2, mic_bottom + stand_height - size//40,
         center + base_width//2, mic_bottom + stand_height + size//40],
        start=0, end=180,
        fill='white',
        width=size//30
    )
    
    # Brain wave effect (representing mental health analysis)
    wave_y = center + mic_radius + size // 6
    wave_points = []
    for x in range(center - mic_radius*2, center + mic_radius*2, size//50):
        offset = ((x - center) / 20) 
        y = wave_y + int(15 * (size/512) * (1 if int(offset) % 2 == 0 else -1))
        wave_points.append((x, y))
    
    if len(wave_points) > 1:
        draw.line(wave_points, fill='white', width=size//80, joint='curve')
    
    # Add subtle pulse circles around mic
    for r in range(1, 4):
        radius = mic_radius + r * size // 20
        alpha = int(100 - r * 25)
        overlay = Image.new('RGBA', (size, size), (255, 255, 255, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        overlay_draw.ellipse(
            [center - radius, mic_top + mic_radius//3 - radius//2,
             center + radius, mic_top + mic_radius//3 + radius//2],
            outline=(255, 255, 255, alpha),
            width=size//100
        )
        img = Image.alpha_composite(img.convert('RGBA'), overlay).convert('RGB')
    
    return img

def create_foreground_icon(size=1024):
    """Create adaptive icon foreground (transparent background)"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    mic_radius = size // 4
    
    # Draw microphone in white
    mic_top = center - mic_radius
    mic_bottom = center + mic_radius // 3
    mic_width = mic_radius
    
    draw.rounded_rectangle(
        [center - mic_width//2, mic_top, center + mic_width//2, mic_bottom],
        radius=mic_width//2,
        fill='white',
        width=0
    )
    
    # Grid lines
    grid_spacing = mic_width // 5
    for i in range(3):
        y = mic_top + mic_radius // 3 + i * grid_spacing
        draw.line(
            [(center - mic_width//3, y), (center + mic_width//3, y)],
            fill='#6366F1',
            width=size//100
        )
    
    # Stand
    stand_height = mic_radius // 2
    draw.line(
        [(center, mic_bottom), (center, mic_bottom + stand_height)],
        fill='white',
        width=size//30
    )
    
    # Base
    base_width = mic_radius
    draw.arc(
        [center - base_width//2, mic_bottom + stand_height - size//40,
         center + base_width//2, mic_bottom + stand_height + size//40],
        start=0, end=180,
        fill='white',
        width=size//30
    )
    
    return img

def create_splash_icon(size=512):
    """Create splash screen icon (smaller, centered)"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    mic_radius = size // 3
    
    # Draw microphone
    mic_top = center - mic_radius
    mic_bottom = center + mic_radius // 3
    mic_width = mic_radius
    
    draw.rounded_rectangle(
        [center - mic_width//2, mic_top, center + mic_width//2, mic_bottom],
        radius=mic_width//2,
        fill='white',
        width=0
    )
    
    # Grid
    grid_spacing = mic_width // 5
    for i in range(3):
        y = mic_top + mic_radius // 3 + i * grid_spacing
        draw.line(
            [(center - mic_width//3, y), (center + mic_width//3, y)],
            fill='#8B5CF6',
            width=size//80
        )
    
    # Stand
    stand_height = mic_radius // 2
    draw.line(
        [(center, mic_bottom), (center, mic_bottom + stand_height)],
        fill='white',
        width=size//25
    )
    
    # Base
    base_width = mic_radius
    draw.arc(
        [center - base_width//2, mic_bottom + stand_height - size//30,
         center + base_width//2, mic_bottom + stand_height + size//30],
        start=0, end=180,
        fill='white',
        width=size//25
    )
    
    # Wave effect
    wave_y = center + mic_radius + size // 8
    wave_points = []
    for x in range(center - mic_radius, center + mic_radius, size//40):
        offset = ((x - center) / 15)
        y = wave_y + int(10 * (size/512) * (1 if int(offset) % 2 == 0 else -1))
        wave_points.append((x, y))
    
    if len(wave_points) > 1:
        draw.line(wave_points, fill='white', width=size//60, joint='curve')
    
    return img

# Create output directory
os.makedirs('assets/icon', exist_ok=True)

# Generate icons
print("🎨 Generating app icon (1024x1024)...")
app_icon = create_app_icon(1024)
app_icon.save('assets/icon/app_icon.png', 'PNG')

print("🎨 Generating adaptive icon foreground (1024x1024)...")
foreground = create_foreground_icon(1024)
foreground.save('assets/icon/app_icon_foreground.png', 'PNG')

print("🎨 Generating splash icon (512x512)...")
splash = create_splash_icon(512)
splash.save('assets/icon/splash_icon.png', 'PNG')

print("\n✅ All assets generated successfully!")
print("📁 Files created:")
print("   - assets/icon/app_icon.png")
print("   - assets/icon/app_icon_foreground.png")
print("   - assets/icon/splash_icon.png")
print("\n📱 Next steps:")
print("   1. Run: flutter pub get")
print("   2. Run: dart run flutter_launcher_icons")
print("   3. Run: dart run flutter_native_splash:create")
print("   4. Run: flutter build apk --release")
