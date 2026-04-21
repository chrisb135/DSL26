cat << 'EOF' > test_script.sh
#!/usr/bin/env bash

# Variáveis vindas do ambiente ou padrão
VM_DIR=${VM_DIR:-"./vm"}
IIO_TREE=${IIO_TREE:-"./iio"}
BOOT_DIR=${BOOT_DIR:-"${VM_DIR}/arm64_boot"}

echo "Iniciando Automação de Teste: ADF4350 com RAII Guards..."

expect << 'OUTER_EOF'
    set timeout 300
    spawn qemu-system-aarch64 \
        -M virt,gic-version=3 -m 2G -cpu cortex-a57 -smp 2 \
        -kernel "$env(IIO_TREE)/arch/arm64/boot/Image" \
        -initrd "$env(BOOT_DIR)/initrd.img-6.1.0-43-arm64" \
        -append "console=ttyAMA0 loglevel=8 root=/dev/vda2 rootwait" \
        -drive if=none,file="$env(VM_DIR)/arm64_base_400mb.qcow2",format=qcow2,id=hd \
        -device virtio-blk-pci,drive=hd \
        -drive if=none,file="transfer.img",format=raw,id=hd2 \
        -device virtio-blk-pci,drive=hd2 \
        -nographic -no-reboot

    expect "login:" { send "root\r" }
    expect -re {root@.*[:~]# }

    # 1. Monta o segundo disco (pendrive virtual) que geralmente é o /dev/vdb
    send "mkdir -p /mnt/transfer\r"
    expect -re {root@.*[:~]# }

    send "mount /dev/vdb /mnt/transfer\r"
    expect -re {root@.*[:~]# }

    # 2. Carrega o módulo DIRETAMENTE do arquivo .ko
    send "insmod /mnt/transfer/adf4350.ko\r"
    expect -re {root@.*[:~]# }

    # 2. Localiza o dispositivo no subsistema IIO
    # (Pode ser iio:device0, device1, etc)
    send "cd /sys/bus/iio/devices/iio:device0/\r"
    expect -re {root@.*[:~]# }

    # 3. TESTE DE LOCK: Leitura Dupla
    # Se o guard não liberar o mutex na primeira leitura, a segunda travará.
    puts "\nVerificando liberação de Mutex (Leitura 1)..."
    send "cat name\r"
    expect "adf4350"
    expect -re {root@.*[:~]# }

    puts "\nVerificando liberação de Mutex (Leitura 2 - se travar aqui, o guard falhou)..."
    send "cat name\r"
    expect "adf4350"
    expect -re {root@.*[:~]# }

    # 4. TESTE DE ESCRITA (Triggers write_raw onde o lock costuma ser usado)
    puts "\nTestando escrita de frequência (Modificando registradores)..."
    send "echo 1000000000 > out_altvoltage0_frequency\r"
    expect -re {root@.*[:~]# }

    # 5. TESTE DE ERRO (Forçar um erro para ver se o guard libera no return)
    # Enviando um valor absurdo que o driver deve rejeitar
    puts "\nForçando erro para testar cleanup automático do guard..."
    send "echo 1 > out_altvoltage0_powerdown\r" 
    expect -re {root@.*[:~]# }
    
    # Tenta ler novamente. Se o erro anterior não soltou o lock, aqui trava.
    send "cat name\r"
    expect "adf4350"

    send "poweroff\r"
    expect "Power down"
    exit 0
OUTER_EOF
EOF
chmod +x test_script.sh
