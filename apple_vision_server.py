# FILE: apple_vision_server.py
# PURPOSE: SatyaSetu "Zero-Stack" Cognitive Engine.
# VERSION: 8.6.0 (Final Thermal Stability Release)
# DESCRIPTION: Combined token capping, forced GPU flushing, and greedy decoding.

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
print("   SATYA COGNITIVE BRIDGE v8.6.0")
print("   Intelligence: Florence-2 (Zero-Stack)")
print("="*60)

def initialize_brain():
    try:
        model_id = 'microsoft/Florence-2-base'
        print(f"[ENGINE] Mounting Neural Core: {model_id}...")
        
        config = AutoConfig.from_pretrained(model_id, trust_remote_code=True)
        # Optimization: num_beams=1 requires early_stopping to be False
        config.early_stopping = False 
        
        if not hasattr(config, 'forced_bos_token_id'):
            config.forced_bos_token_id = None
        
        model = AutoModelForCausalLM.from_pretrained(model_id, config=config, trust_remote_code=True)
        processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
        
        # USE METAL (MPS)
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        model.to(device)
        model.eval()
        
        print(f"SUCCESS: Brain active on {device.upper()}.")
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
        # This describes every sub-region including held objects.
        prompt = "<DENSE_REGION_CAPTION>"
        
        with torch.inference_mode():
            inputs = processor(text=prompt, images=image, return_tensors="pt").to(device)
            
            # STABILITY CALIBRATION:
            # 1. max_new_tokens=64: Stops the "Footwear" loop.
            # 2. repetition_penalty=1.3: Forces model to find small objects (pens).
            generated_ids = model.generate(
                input_ids=inputs["input_ids"],
                pixel_values=inputs["pixel_values"],
                max_new_tokens=64,
                num_beams=1,
                repetition_penalty=1.3,
                do_sample=False
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
                box = data['bboxes'][i] # Format: [xmin, ymin, xmax, ymax]
                label = data['labels'][i]
                
                results.append({
                    "label": label.upper(),
                    "box_2d": [
                        float(box[0] / image.width * 1000), 
                        float(box[1] / image.height * 1000), 
                        float(box[2] / image.width * 1000),  
                        float(box[3] / image.height * 1000)  
                    ]
                })

        # CRITICAL: M1 SILICON MEMORY FLUSH
        # This prevents the 5s -> 54s latency death spiral.
        del inputs, generated_ids, image
        if device == "mps":
            torch.mps.empty_cache()
        gc.collect()

        duration = time.time() - start_time
        print(f"[LOG] Result ({duration:.2f}s): {len(results)} regions.")
        return {"response": json.dumps(results)}
        
    except Exception as e:
        print(f"[RUNTIME ERROR] {e}")
        if device == "mps": torch.mps.empty_cache()
        return Response(content=str(e), status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)