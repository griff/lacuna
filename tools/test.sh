calculate_size() {
	var=$1
	eval "a1=\\$\{$var\}"
	eval "a1=$a1"
	a1=`echo $a1 | tr '[:upper:]' '[:lower:]'`
	case $a1 in
	*mb)
		a1=`echo $a1 | tr -d 'mb'`
		a1=`expr $a1 \* 1024 \* 2`
		;;
	*g)
		a1=`echo $a1 | tr -d 'g'`
		a1=`expr $a1 \* 1024 \* 1024 \* 2`
		;;
	*gb)
		a1=`echo $a1 | tr -d 'gb'`
		a1=`expr $a1 \* 1024 \* 1024 \* 2`
		;;
	esac
	eval "$var=$a1"
}
NANO_CODESIZE=1014
calculate_size NANO_CODESIZE
echo $NANO_CODESIZE