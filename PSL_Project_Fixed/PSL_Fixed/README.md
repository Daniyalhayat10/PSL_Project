# 🤟 PSL Urdu Detector — Android App

**Pakistan Sign Language (PSL) Urdu Alphabet Detection**  
Final Year Project 2025

---

## 📱 App Features

- **Real-time sign detection** using device camera
- **36 Urdu alphabet letters** (حروف تہجی) detection
- **Hand landmark visualization** with colored skeleton overlay
- **Urdu Text-to-Speech** (speaks detected letter aloud)
- **Word builder** — accumulate letters into words
- **Alphabet guide** — browse all 36 PSL signs with descriptions
- **Beautiful dark UI** with Urdu Nastaleeq font
- **Front/back camera** switching

---

## 🛠️ Prerequisites

Install these tools **before** building:

| Tool | Version | Download |
|------|---------|----------|
| Flutter SDK | ≥ 3.16 | https://flutter.dev/docs/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio |
| Java JDK | 17 | Bundled with Android Studio |
| Git | Any | https://git-scm.com |

---

## 🚀 Setup & Build Instructions

### Step 1: Install Flutter
```bash
# Download Flutter from https://flutter.dev
# Add to PATH, then verify:
flutter doctor
```
All checks should be ✅ (especially Android toolchain).

---

### Step 2: Clone / Get the project
```bash
# If using git:
git clone https://github.com/kashafnn/Pakistan-Sign-Language-URDU-

# Or just unzip the provided folder
```

---

### Step 3: Add your ML model files

Place these files from your GitHub repo into `assets/models/` and `assets/`:

```
psl_urdu_app/
├── assets/
│   ├── models/
│   │   └── hand_landmark_nn.tflite   ← CONVERT YOUR .h5 MODEL (see below)
│   ├── fonts/
│   │   └── JameelNooriNastaleeq.ttf  ← From your repo
│   └── classes.txt                    ← From your repo
```

---

### Step 4: Convert your Keras model to TFLite

Run this Python script **once** to convert `hand_landmark_nn.h5` → `hand_landmark_nn.tflite`:

```python
# convert_model.py
import tensorflow as tf

# Load your Keras model
model = tf.keras.models.load_model('hand_landmark_nn.h5')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # Quantize for mobile
tflite_model = converter.convert()

# Save
with open('hand_landmark_nn.tflite', 'wb') as f:
    f.write(tflite_model)

print("✅ Model converted! Size:", len(tflite_model) / 1024, "KB")
```

Run it:
```bash
pip install tensorflow
python convert_model.py
```

Then copy `hand_landmark_nn.tflite` to `assets/models/`.

---

### Step 5: Install dependencies
```bash
cd psl_urdu_app
flutter pub get
```

---

### Step 6: Build the APK

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (smaller, faster)
flutter build apk --release

# Split APKs by architecture (smallest)
flutter build apk --release --split-per-abi
```

APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

### Step 7: Install on your phone

**Option A — USB:**
```bash
# Enable USB debugging on your phone first
flutter install
```

**Option B — Copy APK:**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option C — Manual:**
1. Copy `app-release.apk` to your phone
2. Open it with a file manager
3. Allow "Install from unknown sources"
4. Install!

---

## 📁 Project Structure

```
psl_urdu_app/
├── lib/
│   ├── main.dart                    # App entry + theme
│   ├── screens/
│   │   ├── splash_screen.dart       # Loading screen
│   │   ├── home_screen.dart         # Main menu
│   │   ├── detection_screen.dart    # 🎥 MAIN: Camera + ML
│   │   ├── alphabet_guide_screen.dart # All 36 letters
│   │   └── about_screen.dart        # Project info
│   ├── services/
│   │   ├── model_service.dart       # TFLite inference
│   │   └── detection_provider.dart  # State management
│   └── widgets/
│       └── hand_landmark_painter.dart # Skeleton overlay
├── assets/
│   ├── models/hand_landmark_nn.tflite
│   ├── fonts/JameelNooriNastaleeq.ttf
│   └── classes.txt
└── android/
    └── app/src/main/
        ├── AndroidManifest.xml      # Permissions
        └── ...
```

---

## 🧠 How the Detection Works

```
Camera Frame
    ↓
Google ML Kit (Pose/Hand Detection)
    ↓
21 Hand Landmarks (x, y, z × 21 = 63 values)
    ↓
Normalize (relative to wrist, scale by max)
    ↓
TFLite Neural Network (hand_landmark_nn.tflite)
    ↓
Softmax → 36 class probabilities
    ↓
Argmax → Predicted Urdu letter
    ↓
Display + TTS
```

---

## ⚠️ Demo Mode

If the TFLite model file is not found in assets, the app runs in **demo mode** with rule-based hand geometry heuristics. The UI is fully functional — you just need to add your model for real predictions.

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter doctor` fails | Install Android SDK via Android Studio |
| Camera permission denied | Go to phone Settings → Apps → PSL → Permissions |
| Build fails with Kotlin error | Run `flutter clean && flutter pub get` |
| TFLite model not found | Check `assets/models/` path in `pubspec.yaml` |
| Low accuracy | Use the real TFLite model (not demo mode) |
| Urdu font not showing | Verify `JameelNooriNastaleeq.ttf` is in `assets/fonts/` |

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `tflite_flutter` | Run TFLite model on device |
| `camera` | Camera access |
| `google_mlkit_pose_detection` | Hand landmark detection |
| `flutter_tts` | Urdu text-to-speech |
| `permission_handler` | Camera permissions |
| `provider` | State management |
| `google_fonts` | UI typography |

---

## 🇵🇰 PSL Urdu Alphabet (36 Letters)

| # | Urdu | Roman | | # | Urdu | Roman |
|---|------|-------|-|---|------|-------|
| 1 | الف | Alif | | 19 | ش | Sheen |
| 2 | ب | Bay | | 20 | ص | Suad |
| 3 | پ | Pay | | 21 | ض | Zuad |
| 4 | ت | Tay | | 22 | ط | Toay |
| 5 | ٹ | Ttay | | 23 | ظ | Zoay |
| 6 | ث | Say | | 24 | ع | Ain |
| 7 | ج | Jeem | | 25 | غ | Ghain |
| 8 | چ | Chay | | 26 | ف | Fay |
| 9 | ح | Hay | | 27 | ق | Qaaf |
| 10 | خ | Khay | | 28 | ک | Kaaf |
| 11 | د | Daal | | 29 | گ | Gaaf |
| 12 | ڈ | Ddaal | | 30 | ل | Laam |
| 13 | ذ | Zal | | 31 | م | Meem |
| 14 | ر | Ray | | 32 | ن | Noon |
| 15 | ڑ | Rray | | 33 | ں | Noon G. |
| 16 | ز | Zay | | 34 | و | Wao |
| 17 | ژ | Zhay | | 35 | ہ | Hay |
| 18 | س | Seen | | 36 | ی | Yay |

---

*Built with ❤️ for the Pakistani deaf community*
