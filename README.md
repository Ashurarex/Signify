<div align="center">

# ✨ Signify
### 🧠 Intent & Gesture Recognizer

<p align="center">
An AI-powered system that understands <b>human hand gestures</b> and <b>predicts user intent</b> in real time using Computer Vision and Machine Learning.
</p>

<p align="center">

![Python](https://img.shields.io/badge/Python-3.10+-blue?style=for-the-badge&logo=python)
![TensorFlow](https://img.shields.io/badge/TensorFlow-DeepLearning-orange?style=for-the-badge&logo=tensorflow)
![OpenCV](https://img.shields.io/badge/OpenCV-ComputerVision-green?style=for-the-badge&logo=opencv)
![MediaPipe](https://img.shields.io/badge/MediaPipe-HandTracking-red?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

</p>

---

</div>

# 📖 Overview

**Signify** is an intelligent gesture recognition system that combines **Computer Vision**, **Machine Learning**, and **Hand Landmark Detection** to recognize gestures and infer user intent.

The system captures live video from a webcam, extracts hand landmarks using **MediaPipe**, classifies gestures using a trained ML model, and maps them into meaningful intents for interaction.

It enables intuitive **touch-free human-computer interaction**, making communication faster, smarter, and more accessible.

---

# 🚀 Features

✅ Real-time hand tracking

✅ Gesture recognition using AI

✅ Intent prediction engine

✅ Fast webcam inference

✅ MediaPipe landmark detection

✅ Machine Learning classification

✅ Easy to extend with new gestures

✅ Lightweight and portable

---

# 🏗 Project Architecture

```text
                Webcam
                   │
                   ▼
        Frame Acquisition
                   │
                   ▼
     MediaPipe Hand Detection
                   │
                   ▼
      Hand Landmark Extraction
                   │
                   ▼
      Gesture Classification Model
                   │
                   ▼
         Intent Recognition Engine
                   │
                   ▼
          User Output / Action
```

---

# 🛠 Tech Stack

| Category | Technology |
|-----------|------------|
| Language | Python |
| Computer Vision | OpenCV |
| Hand Tracking | MediaPipe |
| Machine Learning | TensorFlow / Scikit-Learn |
| Numerical Computing | NumPy |
| Notebook | Jupyter Notebook |

---

# 📂 Project Structure

```bash
Signify/
│
├── dataset/
│   ├── images/
│   └── labels/
│
├── model/
│   ├── trained_model.h5
│   └── gesture_classifier.pkl
│
├── notebooks/
│   ├── Training.ipynb
│   └── Testing.ipynb
│
├── src/
│   ├── detector.py
│   ├── classifier.py
│   ├── predictor.py
│   └── app.py
│
├── requirements.txt
├── README.md
└── LICENSE
```

---

# ⚙ Installation

Clone the repository

```bash
git clone https://github.com/yourusername/Signify.git
```

Move into the project

```bash
cd Signify
```

Create a virtual environment

```bash
python -m venv venv
```

Activate the environment

Windows

```bash
venv\Scripts\activate
```

Linux / Mac

```bash
source venv/bin/activate
```

Install dependencies

```bash
pip install -r requirements.txt
```

---

# ▶ Running the Project

Start the application

```bash
python app.py
```

or

```bash
jupyter notebook
```

Run the notebook if your project is notebook-based.

---

# 🧠 How It Works

1. Capture video from webcam.
2. Detect hands using MediaPipe.
3. Extract 21 hand landmarks.
4. Convert landmarks into feature vectors.
5. Feed features into the trained ML model.
6. Predict gesture.
7. Convert gesture into user intent.
8. Display the recognized result.

---

# 🎯 Supported Gestures

| Gesture | Intent |
|----------|---------|
| 👍 Thumbs Up | Accept |
| 👎 Thumbs Down | Reject |
| ✋ Palm | Stop |
| 👆 Point | Select |
| ✌ Peace | Continue |
| 👌 OK | Confirm |

*(Customize according to your trained dataset.)*

---

# 📊 Machine Learning Pipeline

```text
Dataset
   │
   ▼
Preprocessing
   │
   ▼
Feature Extraction
   │
   ▼
Model Training
   │
   ▼
Evaluation
   │
   ▼
Real-Time Prediction
```

---

# 📈 Future Improvements

- Voice command integration
- Dynamic gesture recognition
- Sentence generation
- Mobile application
- Multi-hand detection
- Sign language translation
- Cloud deployment
- Custom gesture training

---

# 📷 Screenshots

```
Add screenshots here

screenshots/
│
├── home.png
├── prediction.png
├── webcam.png
```

Example:

```markdown
![Home](screenshots/home.png)

![Prediction](screenshots/prediction.png)
```

---

# 🤝 Contributing

Contributions are welcome.

1. Fork the repository
2. Create a feature branch

```bash
git checkout -b feature-name
```

3. Commit changes

```bash
git commit -m "Added new feature"
```

4. Push

```bash
git push origin feature-name
```

5. Open a Pull Request

---

# 📜 License

This project is licensed under the MIT License.

---

# 👨‍💻 Author

**Neha M**

Electronics & Telecommunication Engineering

AI • Computer Vision • Machine Learning • Software Engineering

---

<div align="center">

### ⭐ If you found this project useful, consider giving it a star!

Made with ❤️ using Python, OpenCV, MediaPipe and Machine Learning.

</div>
