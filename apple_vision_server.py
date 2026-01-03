# FILE: apple_vision_server.py
# PURPOSE: SatyaSetu "Contextual Eye" Engine.
# VERSION: 8.7.0 (Contextual Awareness Release)
# DESCRIPTION: Adds Global Scene Captioning to provide environment context 
# to the Intent Engine without needing Gemini API calls for every object.

import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoConfig
from PIL import Image
import torch
import io, base64
import json
import time
import os
import gc

app = FastAPI()

def initialize_brain():
    try:
        model_id = 'microsoft/Florence-2-base'
        config = AutoConfig.from_pretrained(model_id, trust_remote_code=True)
        config.early_stopping = False 
        model = AutoModelForCausalLM.from_pretrained(model_id, config=config, trust_remote_code=True)
        processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        model.to(device)
        model.eval()
        return model, processor, device
    except Exception as e:
        os._exit(1)

model, processor, device = initialize_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    start_time = time.time()
    try:
        payload = await request.json()
        img_data = base64.b64decode(payload['images'][0])
        image = Image.open(io.BytesIO(img_data)).convert("RGB")
        
        # --- TASK 1: DENSE REGION CAPTION (The Objects) ---
        dense_prompt = "<DENSE_REGION_CAPTION>"
        # --- TASK 2: DETAILED CAPTION (The Environment) ---
        scene_prompt = "<DETAILED_CAPTION>"
        
        results = []
        scene_context = ""

        with torch.inference_mode():
            # 1. Perception Pulse
            inputs = processor(text=dense_prompt, images=image, return_tensors="pt").to(device)
            generated_ids = model.generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64, num_beams=1)
            response_text = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
            prediction = processor.post_process_generation(response_text, task=dense_prompt, image_size=(image.width, image.height))
            
            # 2. Context Pulse (Understand the environment locally)
            scene_inputs = processor(text=scene_prompt, images=image, return_tensors="pt").to(device)
            scene_ids = model.generate(input_ids=scene_inputs["input_ids"], pixel_values=scene_inputs["pixel_values"], max_new_tokens=32)
            scene_context = processor.batch_decode(scene_ids, skip_special_tokens=True)[0]

        data = prediction[dense_prompt]
        if 'bboxes' in data:
            for i in range(len(data['bboxes'])):
                box = data['bboxes'][i]
                label = data['labels'][i]
                results.append({
                    "label": label.upper(),
                    "box_2d": [float(box[0]/image.width*1000), float(box[1]/image.height*1000), float(box[2]/image.width*1000), float(box[3]/image.height*1000)]
                })

        torch.mps.empty_cache()
        gc.collect()

        # Return both objects and the overall scene context
        return {
            "response": json.dumps(results),
            "context": scene_context # e.g. "a vegetable market stall with various items"
        }
        
    except Exception as e:
        if device == "mps": torch.mps.empty_cache()
        return Response(content=str(e), status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)