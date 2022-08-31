# Double VPN with OpenVPN
Double VPN with OpenVPN / двойной vpn как сделать / double vpn своими руками / How to chain two OpenVPN servers

Debian / Ubuntu

Debian >= 10

Ubuntu >= 16.04

**Тестировано на Debian 10**

**Tested Debian 10**

Покупаешь 2 сервака VPS

На первый сервак закидываешь **server1.sh**

На второй **server2.sh**

Можешь через редактор nano

```bash
nano server1.sh
CTRL+O
CTRL+X
```

Устанавливаешь screen чтобы при обрыве связи не оборвалась установка

```bash
apt update -y
apt install screen
```

Создание скрина f

```bash
screen -S f
```
Отправка скрина в фон

```bash
CTRL+A+D
```
Возврат к скрину

```bash
screen -r f
```

Далее на все файлы ставишь права 777

```bash
chmod 777 server1.sh
chmod 777 server2.sh
```

Заходишь в скрин и запускаешь

Вначале сервер 1

```bash
./server1.sh
```
После установки первого, второй

```bash
./server2.sh
```

Генерация ключей занимает до 15 минут, воткнул самые пизд-е

## Проверено на DNS утечки

Можешь проверить сам, для этого на первый и второй сервак повесь прослушку

```bash
tcpdump -nnni eth0 udp port 53
tshark -i eth0 -f "port 53"
```

На первом серваке лог будет пустым, на втором будет идти

ДНС сервер будет тот что указан у тебя на компе, а не в файле клиента

Замени на компе на тот который хочешь


## Настройка файрвола

Чтобы трафик не шел мимо впн

Замени интерфейс eth0 на свой, узнать имя так

```bash
ifconfig
```
Замени 111.111.111.111 на IP первого сервака

```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -s 111.111.111.111 -p tcp -m tcp --sport 443 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT
iptables -A OUTPUT -d 111.111.111.111 -o eth0 -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-host-prohibited

ip6tables -A INPUT -j DROP
ip6tables -A FORWARD -j DROP
ip6tables -A OUTPUT -j DROP
```

## Доп инфо

Если разбираешься в роутах, то можешь допилить и дополнить мои труды

В коде есть лишнее, но и так работат

Используй Whonix и Tails для большей анонимности




