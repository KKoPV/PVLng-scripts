Add to cron tab:

 ```
# Send default data
*   *   *   *   *   ~/ws2300/send.sh -c it,ot,dp,wc,ih,oh,rh,pr,ten,for,ws,wt >/dev/null

# Send wind data
*   *   *   *   *   sleep 20 && ~/ws2300/send.sh -c ws,wt >/dev/null
*   *   *   *   *   sleep 40 && ~/ws2300/send.sh -c ws,wt >/dev/null
 ```

Please refer for the keys to `measures.txt`.
