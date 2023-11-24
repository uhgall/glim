'''
### library ( python )

import asyncio
import concurrent.futures

class AsyncAPI:
    def __init__(self):
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=5)

    def Queue(self, function, *args):
        loop = asyncio.get_event_loop()
        return loop.run_in_executor(self.executor, function, *args)

asyncApi = AsyncAPI()

### problem specific code

def Q(model, task):
    ## write the actual code for api call
    pass

def f(*results):
    ## write the actual code for analyze code
    pass

def g(*results):
    ## write the actual code for summarize 
    pass

prompt2_analyze_code = f( asyncApi.Queue(Q,m1,prompt1_write_code), asyncApi.Queue(Q,m2,prompt1_write_code), asyncApi.Queue(Q,m3,prompt1_write_code) ) 
prompt3_summarize = g( asyncApi.Queue(Q,m1,prompt2_analyze_code), asyncApi.Queue(Q,m2,prompt2_analyze_code) )
result = asyncApi.Queue(Q, m1, prompt3_summarize)
'''