#!/usr/bin/env python

import cgi
import os
import urllib
import string
form = cgi.FieldStorage()

print "Content-type: text/html"
print
print "<HTML><HEAD><TITLE>Tape scanner</TITLE></HEAD>"

box = ""
history = []

if "box" in form and form["box"].value != "": box =  form["box"].value
if "history" in form and form["history"].value != "":
   history = form["history"].value.split(",")
if "tape" in form: history.append(form["tape"].value)

agent = os.environ['HTTP_USER_AGENT']
uri = os.environ['REQUEST_URI']
if "?" in uri:
 uri = uri[:uri.index("?")]
  
back_here = 'http://' + os.environ['HTTP_HOST'] + uri 
history_content = '&history=' + string.join(history,',')
if box == "":
 scan_text = "Scan a box"
 generic_text = "Type in a box or location"
 scanning_content = "box={CODE}"
 box_content = ""
 dumb_client = "box"
else:
 scan_text = "Scan a tape"
 generic_text = "Type in a tape name"
 scanning_content = "tape={CODE}"
 box_content = "&box=" + box 
 dumb_client = "tape"

ret_address = urllib.quote_plus(back_here + "?" + scanning_content + history_content + box_content)
if 'Android' in agent: platform = 'android'
elif 'iPhone' in agent: platform = 'iphone'
else: platform = 'unknown'

if platform == 'android': scan_url = 'http://zxing.appspot.com/scan?ret='+ret_address
elif platform == 'iphone': scan_url = 'zxing://scan/?ref='+ret_address
else: scan_url = None

focus = "document.zapform." + dumb_client + ".focus();"
clear_page = 'document.body.innerHTML=\\\"processing...\\\";'
print "<BODY ONLOAD=\"" + focus +"\" "
print "ONUNLOAD=\"" + clear_page + "\" >"
if scan_url is not None:
  print "<a href=\"" + scan_url + "\"><font size=+1>" + scan_text + "</font></a>"
  print "or" 
print generic_text + "<form name=zapform method=get>"
save_history = string.join(history,",").replace("\\","\\\\").replace('"','\"')
print "<input type=hidden name=history value=\"" + save_history + "\">"
if dumb_client == "tape":
   print "<input type=hidden name=box value=\"" + urllib.quote_plus(box)+"\">" 
print "<input type=text name=\"" + dumb_client + "\">"
print "<input type=submit value=\"&gt;&gt;\">"
print "</form>"

print "<hr>"
if box != "" and history != []:
 print "You have scanned the following tapes into the box / location <b>"+box+"</b>"
 print "<ul><li>",string.join(history,"</li>\n<li>"),"</li></ul>"
elif box != "":
 print "You will scan tapes into the box / location <b>"+box+"</b>"


if history != [] and box != "":
 cmd_text = []
 for rawtape in history:
   tape = filter(lambda x: x in string.digits + string.letters + "_-/ ",rawtape)
   box = filter(lambda x: x in string.digits + string.letters + "_-/ ",form["box"].value)
   cmd = ["omnimm","-modify_medium"]
   if " " in tape:
     cmd.append('"' + tape + '"')
     cmd.append('"' + tape + '"')
   else:
     cmd.append(tape)
     cmd.append(tape)
   if " " in box:
     cmd.append('"' + box + '"')
   else:
     cmd.append(box)
   cmd_text.append(string.join(cmd," ")) 
 mailto_body = urllib.quote(string.join(cmd_text,"\n"))
 mailto_link = "mailto:?Subject=Tapes+in+box+"+urllib.quote_plus(box)+"&body="+mailto_body
 print "Click to send these commands as an email to yourself: <a href=\"" + mailto_link + "\"<quote><pre>"
 print string.join(cmd_text,"\n")
 print "</pre></quote></a>"

print "<FORM METHOD=GET><INPUT TYPE=SUBMIT VALUE=\"Start a new box or location\"></FORM>"
#print "<small><quote><pre>"
#for k in os.environ.keys(): print k,"=",os.environ[k]
#print "</pre></quote></small>"
print "</body></HTML>"

