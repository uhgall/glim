 ### library (ruby)
# no lib needed

### problem specific code

m1 = Q.async(:prompt1_write_code)
m2 = Q.async(:prompt1_write_code) 
m3 = Q.async(:prompt1_write_code)

m1.wait
m2.wait
m3.wait

prompt2_analyze_code = f.async(m1, m2, m3)

m1.wait
m2.wait 
m3.wait

prompt3_summarize = g.async(m1, m2)

result = prompt3_summarize.wait