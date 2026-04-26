import csv
import copy
import itertools
from collections import Counter, deque
from typing import List

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

from model import KeyPointClassifier, PointHistoryClassifier

# Load labels
def load_labels():
    with open('model/keypoint_classifier/keypoint_classifier_label.csv', encoding='utf-8-sig') as f:
        keypoint_labels = [row[0] for row in csv.reader(f)]
    with open('model/point_history_classifier/point_history_classifier_label.csv', encoding='utf-8-sig') as f:
        point_history_labels = [row[0] for row in csv.reader(f)]
    return keypoint_labels, point_history_labels

keypoint_classifier_labels, point_history_classifier_labels = load_labels()

# Initialize models
keypoint_classifier = KeyPointClassifier()
point_history_classifier = PointHistoryClassifier(score_th=0.9)

# Global State for a single active session (Hackathon mode)
history_length = 16
point_history = deque(maxlen=history_length)
finger_gesture_history = deque(maxlen=8)

app = FastAPI(title="Hand Gesture Bridge API")

@app.get("/")
def read_root():
    return {
        "status": "online",
        "message": "Hand Gesture Bridge API is running. Visit /docs to test the endpoints."
    }


class Landmark(BaseModel):
    x: float
    y: float
    z: float = 0.0

class PredictRequest(BaseModel):
    landmarks: List[Landmark]
    image_width: int = 960
    image_height: int = 540

def pre_process_landmark(landmark_list):
    temp_landmark_list = copy.deepcopy(landmark_list)

    # Convert to relative coordinates
    base_x, base_y = 0, 0
    for index, landmark_point in enumerate(temp_landmark_list):
        if index == 0:
            base_x, base_y = landmark_point[0], landmark_point[1]

        temp_landmark_list[index][0] = temp_landmark_list[index][0] - base_x
        temp_landmark_list[index][1] = temp_landmark_list[index][1] - base_y

    # Convert to a one-dimensional list
    temp_landmark_list = list(itertools.chain.from_iterable(temp_landmark_list))

    # Normalization
    max_value = max(list(map(abs, temp_landmark_list)))

    def normalize_(n):
        return n / max_value if max_value != 0 else 0

    temp_landmark_list = list(map(normalize_, temp_landmark_list))
    return temp_landmark_list

def pre_process_point_history(image_width, image_height, point_history):
    temp_point_history = copy.deepcopy(point_history)

    # Convert to relative coordinates
    base_x, base_y = 0, 0
    for frame_index, frame_landmarks in enumerate(temp_point_history):
        if frame_index == 0:
            # base_x, base_y is the wrist of the first frame
            if len(frame_landmarks) > 0:
                base_x, base_y = frame_landmarks[0], frame_landmarks[1]

        # For every coordinate pair in the frame
        for i in range(0, len(frame_landmarks), 2):
            frame_landmarks[i] = (frame_landmarks[i] - base_x) / image_width
            frame_landmarks[i+1] = (frame_landmarks[i+1] - base_y) / image_height

    # Convert to a one-dimensional list
    temp_point_history = list(itertools.chain.from_iterable(temp_point_history))
    return temp_point_history

@app.post("/predict")
def predict_intent(request: PredictRequest):
    global point_history, finger_gesture_history
    
    if len(request.landmarks) != 21:
        return {"error": f"Expected exactly 21 landmarks, got {len(request.landmarks)}"}
        
    # Reconstruct landmark list (pixels)
    landmark_list = []
    for lm in request.landmarks:
        landmark_x = min(int(lm.x * request.image_width), request.image_width - 1)
        landmark_y = min(int(lm.y * request.image_height), request.image_height - 1)
        landmark_list.append([landmark_x, landmark_y])

    # Conversion to relative coordinates / normalized coordinates
    pre_processed_landmark_list = pre_process_landmark(landmark_list)
    
    # Hand sign classification (Static)
    hand_sign_id = keypoint_classifier(pre_processed_landmark_list)
    
    # Update point history (Dynamic)
    flattened_landmarks = list(itertools.chain.from_iterable(landmark_list))
    point_history.append(flattened_landmarks)

    pre_processed_point_history_list = pre_process_point_history(
        request.image_width, request.image_height, point_history)

    # Finger gesture classification
    finger_gesture_id = 0
    point_history_len = len(pre_processed_point_history_list)
    if point_history_len == (history_length * 42):
        finger_gesture_id = point_history_classifier(pre_processed_point_history_list)

    # Replicate custom dynamic gesture rules
    movement_distance = 0
    valid_frames = [p for p in point_history if sum(p) != 0]
    if len(valid_frames) > 0:
        for i in range(42):
            coords = [p[i] for p in valid_frames]
            dist = max(coords) - min(coords)
            if dist > movement_distance:
                movement_distance = dist

    if movement_distance < 50:
        finger_gesture_id = 0
    elif len(valid_frames) < 10:
        finger_gesture_id = 0
    else:
        if finger_gesture_id == 1:  # Hungry
            if hand_sign_id != 5:  # Must be C-shape (5)
                finger_gesture_id = 0
            else:
                wrist_y_start = valid_frames[0][1]
                wrist_y_end = valid_frames[-1][1]
                if wrist_y_end < wrist_y_start + 40:
                    finger_gesture_id = 0
        elif finger_gesture_id == 2:  # SOS
            if hand_sign_id != 1: # Must end with closed fist (1)
                finger_gesture_id = 0
            else:
                start_dist = (valid_frames[0][0] - valid_frames[0][16])**2 + (valid_frames[0][1] - valid_frames[0][17])**2
                end_dist = (valid_frames[-1][0] - valid_frames[-1][16])**2 + (valid_frames[-1][1] - valid_frames[-1][17])**2
                if end_dist > start_dist * 0.7:
                    finger_gesture_id = 0
        elif finger_gesture_id == 3:  # Water
            if hand_sign_id != 6: # Must be W-shape (6)
                finger_gesture_id = 0
            else:
                tip_y_values = [f[17] for f in valid_frames]
                direction_changes = 0
                for i in range(2, len(tip_y_values)):
                    prev_delta = tip_y_values[i-1] - tip_y_values[i-2]
                    curr_delta = tip_y_values[i] - tip_y_values[i-1]
                    if prev_delta * curr_delta < 0 and abs(prev_delta) > 3 and abs(curr_delta) > 3:
                        direction_changes += 1
                if direction_changes < 1:
                    finger_gesture_id = 0

    finger_gesture_history.append(finger_gesture_id)
    most_common_fg_id = Counter(finger_gesture_history).most_common()
    final_gesture_id = most_common_fg_id[0][0]

    dynamic_text = point_history_classifier_labels[final_gesture_id]
    if final_gesture_id == 0:
        dynamic_text = ""
        
    hand_sign_text = ""
    if hand_sign_id != -1:
        hand_sign_text = keypoint_classifier_labels[hand_sign_id]

    # Generate intent output
    intent = ""
    message = ""
    
    if dynamic_text == "SOS":
        intent = "SOS"
        message = "Emergency: Need Help!"
    elif dynamic_text == "Hungry":
        intent = "Hungry"
        message = "I am hungry."
    elif dynamic_text == "Water":
        intent = "Water"
        message = "I need water."
    elif hand_sign_text:
        intent = hand_sign_text
        message = f"Static Sign: {hand_sign_text}"
    else:
        intent = "None"
        message = "No clear gesture recognized."

    return {
        "intent": intent,
        "message": message,
        "static_sign": hand_sign_text,
        "dynamic_gesture": dynamic_text
    }

@app.post("/reset")
def reset_state():
    global point_history, finger_gesture_history
    point_history.clear()
    finger_gesture_history.clear()
    return {"message": "State reset successfully"}

if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
