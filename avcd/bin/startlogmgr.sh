#!/bin/bash
pythons=('python' 'python2' 'python3')
for py_exec in ${pythons[@]}; do
    py_exec="/usr/bin/$py_exec"
    if [[ -f $py_exec ]]; then
        exec $py_exec $1 
	break;
    fi
done
