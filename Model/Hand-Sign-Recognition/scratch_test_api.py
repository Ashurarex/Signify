import requests
import json
import time
import random

# API endpoint
URL = "http://localhost:8000/predict"

def test_api():
    print("Testing Bridge API...")
    
    # First, let's reset the state so we have a clean slate
    requests.post("http://localhost:8000/reset")
    print("State reset.")

    # We will send 16 frames to fill up the point_history queue.
    # To simulate an SOS gesture, we need:
    # 1. The hand to be in a closed fist shape (hand_sign_id == 1)
    # 2. The distance between the wrist and index finger tip to decrease over the 16 frames.
    
    print("Sending 16 frames of synthetic data...")
    for i in range(16):
        landmarks = []
        # Create 21 synthetic landmarks
        # We will make the "index finger tip" (landmark 8) get closer to the "wrist" (landmark 0)
        # to simulate the fingers closing inward for the SOS gesture.
        
        # Base wrist position
        wrist_x, wrist_y = 0.5, 0.8
        
        # As i goes from 0 to 15, the index tip moves closer to the wrist.
        # This reduces the distance to pass the `end_dist > start_dist * 0.7` check.
        closing_factor = 1.0 - (i / 15.0) * 0.4  # Decreases from 1.0 to 0.6
        index_tip_y = wrist_y - (0.3 * closing_factor)
        
        for j in range(21):
            if j == 0:
                landmarks.append({"x": wrist_x, "y": wrist_y, "z": 0.0})
            elif j == 8: # Index finger tip
                landmarks.append({"x": wrist_x, "y": index_tip_y, "z": 0.0})
            else:
                # Random noise for other points, keeping them roughly in the same area
                landmarks.append({"x": wrist_x + random.uniform(-0.1, 0.1), 
                                  "y": wrist_y - random.uniform(0.1, 0.3), 
                                  "z": 0.0})
                
        payload = {
            "landmarks": landmarks,
            "image_width": 960,
            "image_height": 540
        }
        
        try:
            response = requests.post(URL, json=payload)
            result = response.json()
            print(f"Frame {i+1}: Intent = {result.get('intent')} | Dynamic Gesture = {result.get('dynamic_gesture')}")
        except Exception as e:
            print(f"Failed to connect to API: {e}")
            return
            
        time.sleep(0.05) # Simulate frame rate (20 FPS)
        
    print("\nFinal Result:")
    print(json.dumps(result, indent=2))
    print("\nNote: Since this is synthetic data, it might not perfectly classify as 'SOS' by the neural network,")
    print("but this script successfully demonstrates how a client interacts with the /predict endpoint!")

if __name__ == "__main__":
    test_api()
