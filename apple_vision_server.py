# FILE: apple_vision_server.py
# PURPOSE: SatyaSetu "Atomic Cool-Down" Cognitive Engine.
# VERSION: 8.4.0 (M1 Stability Release)
# DESCRIPTION: Forced GPU cache flushing and token capping to prevent thermal throttling.

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

print("\n" + "="*60)
print("   SATYA COGNITIVE BRIDGE v8.4.0")
print("   Intelligence: Florence-2 (Atomic Cool-Down)")
print("="*60)

def initialize_brain():
    try:
        model_id = 'microsoft/Florence-2-base'
        print(f"[ENGINE] Mounting Neural Core: {model_id}...")
        
        config = AutoConfig.from_pretrained(model_id, trust_remote_code=True)
        # Fix user warning: early_stopping is only for beam search
        config.early_stopping = False 
        
        if not hasattr(config, 'forced_bos_token_id'):
            config.forced_bos_token_id = None
        
        model = AutoModelForCausalLM.from_pretrained(model_id, config=config, trust_remote_code=True)
        processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
        
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        model.to(device)
        model.eval()
        
        print(f"SUCCESS: Dense Perception active on {device.upper()}.")
        return model, processor, device
    except Exception as e:
        print(f"[FATAL] Brain load failure: {e}")
        os._exit(1)

model, processor, device = initialize_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    start_time = time.time()
    try:
        payload = await request.json()
        img_data = base64.b64decode(payload['images'][0])
        image = Image.open(io.BytesIO(img_data)).convert("RGB")
        
        # TASK: DENSE REGION CAPTION
        prompt = "<DENSE_REGION_CAPTION>"
        
        with torch.inference_mode():
            inputs = processor(text=prompt, images=image, return_tensors="pt").to(device)
            
            # OPTIMIZATION: max_new_tokens reduced to 128 to prevent hallucinatory loops
            # num_beams=1 and early_stopping=False ensures fastest greedy search
            generated_ids = model.generate(
                input_ids=inputs["input_ids"],
                pixel_values=inputs["pixel_values"],
                max_new_tokens=128,
                num_beams=1,
                repetition_penalty=1.5 
            )
            
            response_text = processor.batch_decode(generated_ids, skip_special_tokens=False)[0]
            prediction = processor.post_process_generation(
                response_text, 
                task=prompt, 
                image_size=(image.width, image.height)
            )
        
        results = []
        data = prediction[prompt]
        
        if 'bboxes' in data:
            for i in range(len(data['bboxes'])):
                box = data['bboxes'][i] 
                label = data['labels'][i]
                
                # Standardize to 0-1000 scale for Flutter
                results.append({
                    "label": label.upper(),
                    "box_2d": [
                        float(box[0] / image.width * 1000),  # xmin
                        float(box[1] / image.height * 1000), # ymin
                        float(box[2] / image.width * 1000),  # xmax
                        float(box[3] / image.height * 1000)  # ymax
                    ]
                })

        # CRITICAL: M1 GPU MEMORY MANAGEMENT
        del inputs
        del generated_ids
        if device == "mps":
            torch.mps.empty_cache() # Manually flush Apple Silicon GPU RAM
        gc.collect()

        duration = time.time() - start_time
        print(f"[LOG] Identified {len(results)} items in {duration:.2f}s")
        return {"response": json.dumps(results)}
        
    except Exception as e:
        print(f"[RUNTIME ERROR] {e}")
        # Ensure cache is flushed even on error
        if device == "mps": torch.mps.empty_cache()
        return Response(content=str(e), status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)