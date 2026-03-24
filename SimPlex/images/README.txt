UnPlex Image Assets
====================

Required images for the app to function properly:

1. icon_focus_fhd.png (540x405) - App icon shown in Roku home screen when focused
2. icon_side_fhd.png (246x140) - App icon shown in side panel (FHD)
3. icon_focus_hd.png (336x210) - App icon shown when focused (HD)
4. icon_side_hd.png (164x94) - App icon shown in side panel (HD)
5. splash_fhd.jpg (1920x1080) - Splash screen shown during app launch
6. badge-unwatched.png - Unwatched episode count badge overlay
7. spinner.png (80x80) - Loading spinner animation frame

Image Guidelines:
- All images should be in PNG format (except splash which can be JPG)
- Use UnPlex gold (#F3B125) as accent color
- Background should be solid black (#000000)
- Keep file sizes optimized for fast loading

To regenerate branded images (icons, splash):
  python scripts/generate_branding.py
