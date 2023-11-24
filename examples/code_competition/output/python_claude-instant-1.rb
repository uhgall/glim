 '''
### library (python) 
# no lib needed

### problem specific code
import asyncio

async def prompt2_analyze_code():
    tasks = [Q(m1,"prompt1_write_code"), Q(m2,"prompt1_write_code"), Q(m3,"prompt1_write_code")]
    await asyncio.gather(*tasks)

async def prompt3_summarize():
    tasks = [Q(m1, await prompt2_analyze_code()), Q(m2, await prompt2_analyze_code())]
    await asyncio.gather(*tasks)

asyncio.run(prompt3_summarize())
result = Q(m1, await prompt3_summarize())
'''