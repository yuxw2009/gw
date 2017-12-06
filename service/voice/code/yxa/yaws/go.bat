ulimit -n 409600
yaws --name yxa@APS.APS --conf yaws.conf  --erlarg "-setcookie yxwabc -pa ../ebin -pa ../../ebin +K true" 
