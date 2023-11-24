 ### library (python)
# no lib needed

### problem specific code
import asyncio

async def Q(msg, fut):
    await asyncio.sleep(0.1) # pretend this is an API call
    fut.set_result(msg)
    return fut

async def f(m1, m2, m3):
    return [await m1, await m2, await m3]

async def g(m1, m2):
    return m1[0] + m2[1]

prompt1 = asyncio.Future()
prompt1.set_result('code')

m1 = Q('analyzing code 1', asyncio.Future())
m2 = Q('analyzing code 2', asyncio.Future()) 
m3 = Q('analyzing code 3', asyncio.Future())

prompt2 = asyncio.gather(f(m1, m2, m3))

m1 = Q('summary 1', asyncio.Future())
m2 = Q('summary 2', asyncio.Future())

prompt3 = g(m1, m2)

result = asyncio.gather(prompt3)
print(asyncio.run(result))