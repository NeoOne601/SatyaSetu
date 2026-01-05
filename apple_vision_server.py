# FILE: apple_vision_server.py
# VERSION: 10.0.0 (The Unified Local AGI)
# DESCRIPTION: Orchestrates Florence-2 (Retina) and Gemma-2-2b (Logic).
# Both models run locally on iMac MPS (Metal) for Zero-Lag, Zero-API cost.

import uvicorn
from fastapi import FastAPI, Request, Response
from transformers import AutoProcessor, AutoModelForCausalLM, AutoTokenizer
from PIL import Image
import torch
import io, base64, json, time, os, gc

app = FastAPI()

# SHARED STATE FOR NEURAL CORES
brain = {}

def initialize_brain():
    print("============================================================")
    print("   SATYA LOCAL NEURAL HUB v10.0.0")
    print("============================================================")
    
    try:
        device = "mps" if torch.backends.mps.is_available() else "cpu"
        
        # 1. MOUNT RETINA (Florence-2) - Perception Engine
        print("[HUB] Mounting Retina: Florence-2-base...")
        retina_id = 'microsoft/Florence-2-base'
        brain['retina_p'] = AutoProcessor.from_pretrained(retina_id, trust_remote_code=True)
        brain['retina_m'] = AutoModelForCausalLM.from_pretrained(retina_id, trust_remote_code=True).to(device).eval()
        
        # 2. MOUNT COGNITIVE CORE (Gemma-2-2b-it) - Reasoning Engine
        print("[HUB] Mounting Cortex: google/gemma-2-2b-it...")
        cortex_id = 'google/gemma-2-2b-it'
        # We use 4-bit/Float16 to save VRAM on the iMac
        brain['cortex_t'] = AutoTokenizer.from_pretrained(cortex_id)
        brain['cortex_m'] = AutoModelForCausalLM.from_pretrained(
            cortex_id, 
            torch_dtype=torch.float16 if device == "mps" else torch.float32
        ).to(device).eval()
        
        print(f"SUCCESS: Dual-Core Brain Active on {device.upper()}.")
        return True
    except Exception as e:
        print(f"CRITICAL ERROR: Could not load local models: {e}")
        print("Tip: Ensure you ran 'huggingface-cli login' and have access to Gemma models.")
        return False

# Trigger initialization on startup
status = initialize_brain()

@app.post('/v1/vision')
async def vision(request: Request):
    """Retina Loop: Identifies Objects and Scene Context."""
    try:
        payload = await request.json()
        img_data = base64.b64decode(payload['images'][0])
        image = Image.open(io.BytesIO(img_data)).convert("RGB")
        
        results = []
        with torch.inference_mode():
            # 1. OBJECT DETECTION
            inputs = brain['retina_p'](text="<DENSE_REGION_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
            generated_ids = brain['retina_m'].generate(input_ids=inputs["input_ids"], pixel_values=inputs["pixel_values"], max_new_tokens=64)
            prediction = brain['retina_p'].post_process_generation(brain['retina_p'].batch_decode(generated_ids, skip_special_tokens=False)[0], task="<DENSE_REGION_CAPTION>", image_size=(image.width, image.height))
            
            # 2. SCENE CONTEXT
            scene_inputs = brain['retina_p'](text="<DETAILED_CAPTION>", images=image, return_tensors="pt").to(brain['retina_m'].device)
            scene_ids = brain['retina_m'].generate(input_ids=scene_inputs["input_ids"], pixel_values=scene_inputs["pixel_values"], max_new_tokens=32)
            scene_context = brain['retina_p'].batch_decode(scene_ids, skip_special_tokens=True)[0]

        data = prediction["<DENSE_REGION_CAPTION>"]
        for i in range(len(data['bboxes'])):
            box = data['bboxes'][i]
            results.append({
                "label": data['labels'][i].upper(),
                "box_2d": [float(box[0]/image.width*1000), float(box[1]/image.height*1000), float(box[2]/image.width*1000), float(box[3]/image.height*1000)]
            })

        return {"response": json.dumps(results), "context": scene_context}
    except Exception as e:
        return Response(content=str(e), status_code=500)

@app.post('/v1/reason')
async def reason(request: Request):
    """Cortex Loop: Local Gemma-2-2b Reasoning."""
    try:
        payload = await request.json()
        obj = payload.get('object', 'Unknown')
        ctx = payload.get('context', 'General')
        
        # PROMPT: Ask Gemma for 3 relatable, insightful questions about the object
        prompt = f"User is looking at a {obj} in the context of: {ctx}. Suggest 3 short, intriguing questions a user might ask about this object to learn more. Return only the questions as a list."
        
        input_ids = brain['cortex_t'](prompt, return_tensors="pt").to(brain['cortex_m'].device)
        
        with torch.inference_mode():
            outputs = brain['cortex_m'].generate(**input_ids, max_new_tokens=100, do_sample=True, temperature=0.7)
            response_text = brain['cortex_t'].decode(outputs[0], skip_special_tokens=True)
        
        # Simple cleanup of AI response to extract lines
        lines = [line.strip() for line in response_text.replace(prompt, "").split("\n") if line.strip() and "?" in line][:3]
        if not lines: lines = [f"What are the origins of this {obj}?", f"How is this {obj} utilized here?", f"Can you explain the value of {obj}?"]

        return {"questions": lines}
    except Exception as e:
        return {"questions": ["Unable to synthesize local inquiries."]}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)