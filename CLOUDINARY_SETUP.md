# Cloudinary Upload Setup

## Profile Image Upload Configuration

The app uses Cloudinary for uploading profile images. Follow these steps to set it up:

### 1. Create Unsigned Upload Preset

1. Go to [Cloudinary Console](https://console.cloudinary.com/)
2. Navigate to **Settings** → **Upload**
3. Scroll down to **Upload presets**
4. Click **Add upload preset**
5. Configure:
   - **Preset name**: `lost_and_finder_profile` (or any name you prefer)
   - **Signing Mode**: Select **Unsigned**
   - **Folder**: `profile_images` (optional but recommended)
   - **Allowed formats**: jpg, png, webp
   - **Transformation**: 
     - Mode: Scale
     - Width: 512
     - Height: 512
     - Crop: Fill
     - Gravity: Face (for better profile cropping)
6. Click **Save**

### 2. ✅ Code Already Updated

The code is already configured with your preset:
- **Profile images**: `lost_and_finder_profile` preset → `profile_images` folder
- **Item images**: `lost_and_finder_profile` preset → `item_images` folder

### 3. Cloudinary Credentials (✅ Configured)

- **Cloud Name**: `dh6mb70f5`
- **Upload Preset**: `lost_and_finder_profile`
- **Plan**: Free (0/25 credits used)
- **Storage**: 25 GB available

### 4. Testing

1. Run the app
2. Go to Profile screen
3. Click the camera icon on your profile picture
4. Choose Camera or Gallery
5. Select an image
6. The image will be uploaded to Cloudinary and the URL will be saved in Firestore

### Security Notes

- The upload preset is **unsigned**, meaning no API key is required in the app
- This is safe for profile images as Cloudinary restricts upload size and formats
- For production, consider adding:
  - Upload restrictions (file size, dimensions)
  - Rate limiting
  - Content moderation

### Troubleshooting

**Error: "Failed to upload image to Cloudinary"**
- Check your internet connection
- Verify upload preset name is correct
- Ensure preset is set to "unsigned"
- Check Cloudinary dashboard for upload errors

**Image not displaying:**
- Verify Firestore has the `photoUrl` field
- Check the URL format (should start with https://res.cloudinary.com/)
- Clear app cache and restart

### Storage Limits (Free Plan)

- **Storage**: 25 GB
- **Bandwidth**: 25 GB/month
- **Transformations**: 25 credits/month
- More than enough for profile images!
