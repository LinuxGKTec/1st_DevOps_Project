
ubuntu@ip-10-0-1-195:~$ kubectl port-forward svc/linuxgktech 8080:8080
Forwarding from 127.0.0.1:8080 -> 80
Forwarding from [::1]:8080 -> 80


ubuntu@ip-10-0-1-195:~kubectl port-forward --address 0.0.0.0 svc/linuxgktech 8080:808080
Forwarding from 0.0.0.0:8080 -> 80
