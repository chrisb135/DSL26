echo "obj-m += adf4350.o" > Makefile
echo "" >> Makefile
echo "all:" >> Makefile
echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) modules" >> Makefile
echo "" >> Makefile
echo "clean:" >> Makefile
echo -e "\tmake -C /lib/modules/\$(shell uname -r)/build M=\$(PWD) clean" >> Makefile
