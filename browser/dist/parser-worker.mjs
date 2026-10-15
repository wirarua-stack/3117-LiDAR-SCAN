import {parseScan} from './core.mjs';
self.onmessage=e=>{try{self.postMessage({model:parseScan(e.data.text,e.data.name,e.data.scale)});}catch(error){self.postMessage({error:error.message});}};
