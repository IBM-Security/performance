sed 's/->/;/g' < $1 | awk '{sum[$NF]++}END{for (stack in sum) print stack, sum[stack]}' | sort 
