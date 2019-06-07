echo ordinary command
unset x y
x=5 y=$((x+2)) ./getenv x y
echo ${x-x unset after} ${y-y unset after}

echo special builtin
unset x y
x=5 y=$((x+2)) :
echo ${x-x unset after} ${y-y unset after}

echo command special builtin
unset x y
x=5 y=$((x+2)) command :
echo ${x-x unset after} ${y-y unset after}

echo no command
unset x y
x=5 y=$((x+2))
echo ${x-x unset after} ${y-y unset after}

echo redirect
unset x y
x=5 y=$((x+2)) >derp
echo ${x-x unset after} ${y-y unset after}

echo readonly
unset x y
readonly x y
x=5 y=$((x+2)) ./getenv x y
echo ${x-x unset after} ${y-y unset after}

[ -f derp ] && rm derp
