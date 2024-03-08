local sfind=string.find
local fmt=string.format
local gsub=string.gsub
local match=string.match
local tinsert=table.insert
local tconcat=table.concat
local urlencode=ba.urlencode
local slower=string.lower
local tonumber=tonumber
local ba=ba
local jEnc=ba.json.encode
local type=type
local _G=_G
local _ENV={}

local xssfilt
do
   local escSyms= {
      ['&']="&amp;",
      ['<']="&lt;",
      ['>']="&gt;",
      ['"']="&quot;",
      ["'"]="&#x27;",
      ['/']="&#x2F;"
   }
   local function escape(c) return escSyms[c] end
   xssfilt=function(x) return gsub(x,"[&<>\"'/]", escape) end
end


local header1=
[[<!DOCTYPE html>
<html lang="en">
<head>
<!-- Generated by the Barracuda Web File Manager; http://www.realtimelogic.com/ -->
<meta http-equiv="content-type" content="text/html;charset=utf-8" />
<link href='/rtl/wfm/style.css' rel='stylesheet' type='text/css' />
<script>window.enableCtxMenu=true;</script>
<script src='/rtl/jquery.js'></script>
<script src='/rtl/wfm/wfm.js'></script>
<title>]]

local header2=
[[</title></head><body><div id="overlaymask"></div><div id='menu'><div>]]

local function createHelpDiv(logouturi,helpuri)
   if logouturi or helpuri then
      local t={}
      tinsert(t,"<span id='help'>")
      if logouturi then
	 tinsert(t,fmt([[<a id='LogoutB' href='%s' title='Logout'></a>]],logouturi))
      end
      if helpuri then
	 tinsert(t,fmt([[<a id='HelpB' href='%s' title='Help' target='help'></a>]],helpuri))
      end
      tinsert(t,"</span>")
      return tconcat(t)
   end
   return ""
end


local menubuts=
[[<span id='menulinks'><a id='RefreshB' href='./' title='Refresh'></a><a id='NewFolderB' href='./?cmd=mkdir' title='Create a new directory'></a><a id='UploadB' href='./?cmd=upload' title='Upload a file from your drive to the remote drive'></a><a id='NewWindowB' href='./' target='_blank' title='Open New Window'></a><a id='SearchB' href='#' title='Search for resources'></a>]]

function add2menubuts(data)
   menubuts=menubuts..data
end

local hdavbut=
[[<a href='#' id='WebDAVB' title='WebDAV session URL'></a>]]

local header4=
[[</span></div><span id='navlink'>Path: ]]

function manageMicrosoftClient(cmd,rel)
   return false
end
local manageMicrosoftClient=manageMicrosoftClient


local function trim(s)
   if s then
      return s:gsub("^%s*(.-)%s*$", "%1")
   end
end

local function addpath(path,name)
   return fmt("%s/%s",path,name):gsub("//","/")
end

local function emitHtmlHeader(_ENV,cmd,rel,title)
   if davbut then
      cmd:write(header1,title,header2,helpdiv,menubuts,hdavbut,header4)
   else
      cmd:write(header1,title,header2,helpdiv,menubuts,header4)
   end
   local path=""
   local dir=""
   local dirs={}
   for n in rel:gmatch("([^/]+)") do
      tinsert(dirs,n)
   end
   local level = #dirs
   if level > 0 then
      function emitLink(level, name)
	 cmd:write"<a href='"
	 for l=1,level do
	    cmd:write"../"
	 end
	 cmd:write("'>",name,"</a> / ")
      end
      emitLink(level, "top")
      for l=1,(level-1) do
	 emitLink(level-l, dirs[l])
      end
      dir = dirs[level]
   end
   cmd:write("</span><span id='curdir'>Directory: ", dir,"</span></div>")
end


local function emitHtmlFooter(cmd)
   cmd:write"</body></html>"
end

local function isAjaxReq(_ENV)
   if jsonrsp or (cmd.header and cmd:header"x-requested-with") then
      return true
   end
   return false
end

local function getLockOwner(_ENV,rel)
   local owner
   local xml,time=dav:lockmgr(rel,true)
   if xml then
      owner=xml:match"href%s*>([^<]+)<"
   end
   owner=owner or "unknown"
   time=time or 0
   return owner,time
end


local function checklock(_ENV,rel)
   if dav:lockmgr(rel) then
      local owner=getLockOwner(_ENV,rel)
      owner = " by "..owner or ""
      if not cmd.write then cmd=cmd:response() end
      if isAjaxReq(_ENV) then
	 cmd:json{err="noaccess",emsg=fmt("%s is locked%s.",rel,owner)}
      end
      cmd:setstatus(403)
      if txtrsp then
	 cmd:write(rel," is locked",owner,'.')
      else
	 emitHtmlHeader(_ENV,cmd,rel,"File Locked")
	 cmd:write("<h1>File Locked</h1><p>",rel," is locked",owner,".</p>")
	 cmd:write"<p>Press the back button to continue.</p>"
	 emitHtmlFooter(cmd)
      end
      cmd:abort()
   end
end

local function sendresp(_ENV,emsg,ok,err,exterr)
   local function send(data)
      local len=data and #data or 0
      cmd:setcontentlength(len)
      if data then cmd:send(data,len) end
   end
   local ajax = isAjaxReq(_ENV)
   if ajax then
      cmd:setheader("Content-Type","application/json")
   end
   if ok then
      if ajax then
	 send(jEnc{ok=true})
      elseif txtrsp then
	 send"ok"
      else
	 -- Send a redirect request
	 cmd:setstatus(302)
	 cmd:setheader("Location",url or cmd:url():gsub("[^/]$",""))
	 send()
      end
   else
      if type(emsg) == "function" then emsg=emsg() end
      local e2info={
	 invalidname="Invalid name",
	 notfound="Not found",
	 exist="Resource exist",
	 enoent="No such file or directory",
	 noaccess="No file system access",
	 notempty="Directory not empty",
	 ioerror="File system error",
	 nospace="No space left on file system"
      }
      local info=e2info[err]
      info = info or err
      if exterr and #exterr > 1 then
	 info=fmt("%s.\n%s",info,exterr)
      end
      if ajax then
	 cmd:write(jEnc{err=err,emsg=fmt("%s: %s.",emsg,info)})
      else
	 local e2http={
	    invalidname=400,
	    notfound=404,
	    exist=405,
	    enoent=409,
	    noaccess=403,
	    notempty=409,
	    nospace=503,
	 }
	 local status=e2http[err]
	 cmd:setstatus(status or 503)
	 if txtrsp then
	    cmd:write(fmt("Operation failed:\n%s.\n%s.", emsg,info))
	 else
	    emitHtmlHeader(_ENV,cmd,"",emsg)
	    cmd:write("<h1>Operation Failed</h1><p>",emsg,"<br/>",info,".</p>")
	    cmd:write"<p>Press the back button to continue.</p>"
	    emitHtmlFooter(cmd)
	 end
      end
   end
   cmd:abort()
end

local asyncSendresp
if ba.thread and ba.thread.run then -- If installed
   asyncSendresp=function(_ENV,emsg,ok,err,exterr)
      ba.thread.run(function() sendresp(_ENV,emsg,ok,err,exterr) end)
   end
else
   asyncSendresp=sendresp
end

local function manageFilesErr(_ENV,err)
   if response:committed() then return end
   local emsg,err=err:match"[^:%s]+:%s([^%(]+)%(([^%)]+)"
   err = err or "noaccess"
   emsg = emsg or err
   response:reset"buffer"
   sendresp(_ENV,emsg,false,err)
end


local function checkresp(_ENV,emsg,ok,err,exterr)
   if ok then return end
   sendresp(_ENV,emsg,ok,err,exterr)
end


local function doNothing() end

local nolist={["."]=true,[".."]=true,[".DAV"]=true,[".LOCK"]=true}


local function newWFS(name,priority,io,lockdir,maxuploads,maxlocks)
   local authenticate,authorize=doNothing,doNothing  -- Default
   local dav,resrdr,sesTmo,hasAuth,hasSesUri
   local helpdiv=""
   local uploader=ba.create.upload(io)
   local helpuri
   local ctxmuri="/rtl/wfm/ctxmenu.js"

   local function dohelpuri(_ENV,rel)
      cmd:json{uri=helpuri}
   end

   local function sessionuri(_ENV,rel)
      local id
      local uri
      if hasSesUri then
	 local s = cmd:session()
	 id = s and s:id(true)
      end
      if id then
	 uri=fmt("%s%s/%s",resrdr:baseuri(),id,rel)
      else
	 tmo=0
	 uri=fmt("%s%s",resrdr:baseuri(),rel)
      end
      cmd:json{tmo=sesTmo,uri=uri}
   end

   local function tzone(cmd)
      local tzone=cmd:cookie"tzone"
      if tzone then
	 tzone = tonumber(tzone:value())
	 if tzone then return tzone*60 end
      end
   end


   local function ls(_ENV,rel)
      authorize(_ENV, rel, "PROPFIND",false)
      response:setdefaultheaders()
      local dir=rel:match("[^/]*/$")
      if not dir then
	 if #rel > 0 then return false end
	 dir="top"
      end
      emitHtmlHeader(_ENV,cmd,rel, "Directory "..dir)
      cmd:write"<div id='resources'><div id='fstab'><table><thead><tr><th>Name</th><th>Size</th><th>"
      local tzone=tzone(cmd)
      if tzone then
	 cmd:write"Local"
      else
	 tzone=0
	 cmd:write"UTC"
      end
      cmd:write" Date</th></tr></thead><tbody>"
      local function action()
	 local dav=dav
	 for n,isdir,mtime,size in io:files(rel,true) do
	    if not nolist[n] then
	       local link = urlencode(isdir and (n.."/") or n)
	       local len = #n
	       local lock=dav:lockmgr(rel..n) and '<span class="lock"></span>' or ''
	       if len > 60 then
		  cmd:write("<tr><td>",lock,"<a href='",link,"' title='",n,"'>",n:sub(len-60),"</a></td>")
	       else
		  cmd:write("<tr><td>",lock,"<a href='",link,"'>",n,"</a></td>")
	       end
	       if isdir then
		  cmd:write("<td><img class='dir' src='/rtl/wfm/folder.png' alt='DIR'/></td>")
	       else
		  cmd:write("<td>",size,"</td>")
	       end
	       cmd:write("<td>",os.date("!%Y-%m-%d %H:%M",mtime+tzone),"</td></tr>\n")
	    end
	 end
	 return true
      end
      local ok,err=pcall(action)
      if not ok then manageFilesErr(_ENV,err) end
      cmd:write"</tbody></table></div></div>"
      emitHtmlFooter(cmd)
   end

   local function lj(_ENV,rel)
      jsonrsp=true
      authorize(_ENV, rel, "PROPFIND",true)
      response:setheader("Content-Type","application/json")
      local isFirst=true
      cmd:write"["
      local function action()
	 for name,isdir,time,size in io:files(rel,true) do
	    if not nolist[name] then
	       if isFirst then
		  isFirst=false
	       else
		  cmd:write","
	       end
	       cmd:write(jEnc({n=name,s=(isdir and -1 or size),t=time}))
	    end
	 end
	 return true
      end
      local ok,err=pcall(action)
      if not ok then manageFilesErr(_ENV,err) end
      cmd:write"]"
   end

   local function mkdir(_ENV,rel,isPost,txtrsp)
      _ENV.txtrsp=txtrsp
      local dir=cmd:data"dir"
      if dir and (isPost or txtrsp) then
	 rel = rel..dir
	 authorize(_ENV, rel, "MKCOL")
	 sendresp(_ENV,"Cannot create "..rel,io:mkdir(rel))
      else
	 emitHtmlHeader(_ENV,cmd,rel,"Create Directory")
	 cmd:write("<form method='post'><p>Create a new subdirectory in the ",
		   rel,
		   " directory.</p><p>Directory name: <input type='text' size='20' name='dir' value=''/></p><input type='Submit' value='Create directory'/></form>")
	 emitHtmlFooter(cmd)
      end
   end

   local function mv(_ENV,rel) -- Designed exclusively for NetIo
      _ENV.txtrsp = true;
      local data=request:data()
      local from,to=trim(data.from),trim(data.to)
      if from and to then
	 local st = io:stat(rel)
	 if st and st.isdir then
	    from = addpath(rel,from)
	    authorize(_ENV, from, "DELETE")
	    authorize(_ENV, to, "PUT")
	    local function errmsg()
	       return fmt("Cannot rename %s -> %s",from, to)
	    end
	    checkresp(_ENV,errmsg,io:rename(from,to:sub(#resrdr:baseuri())))
	    sendresp(_ENV,nil,true)
	 end
      end
      sendresp(_ENV,rel,false,"notfound")
   end

   local function DELETE(_ENV,rel,notTxtrsp)
      _ENV.txtrsp = not notTxtrsp;
      local curname
      local function errmsg() return fmt("Cannot delete %s",curname) end
      local function delRes(fn, isdir)
	 authorize(_ENV, fn, "DELETE")
	 checklock(_ENV,fn)
	 curname=fn
	 if isdir then
	    for f,i in io:files(fn,true) do
	       if not nolist[f] then
		  delRes(fmt("%s/%s",fn,f),i)
	       end
	    end
	    checkresp(_ENV,errmsg,io:rmdir(fn))
	 else
	    checkresp(_ENV,errmsg,io:remove(fn))
	 end
	 return true
      end
      local len = #rel
      if rel:sub(len) == "/" then
	 rel = rel:sub(1,len-1)
      end
      curname=rel
      local st = io:stat(rel)
      if st then
	 local ok,err=pcall(delRes,rel,st.isdir)
	 if not ok then manageFilesErr(_ENV,err) end
	 sendresp(_ENV,nil,true)
      else
	 sendresp(_ENV,curname,false,"notfound")
      end
   end

   local function remove(_ENV,rel,isPost,txtrsp)
      _ENV.txtrsp = txtrsp;
      local fn = trim(cmd:data("file"))
      if fn and #fn > 0 then
	 if isPost and fn then
	    DELETE(_ENV,rel..fn,not txtrsp)
	 else
	    emitHtmlHeader(_ENV,cmd,rel,"Delete Resource")
	    local st = io:stat(rel..fn)
	    if st then
	       if st.isdir then
		  cmd:write("<p>Do you want to delete ",st.isdir and "directory" or "file"," ",fn,"?</p>")
	       end
	       cmd:write("<form method='post'><input type='hidden' name='file' value='",
			 fn,"'/><input type='Submit' value='Delete'/></form>")
	       emitHtmlFooter(cmd)
	       return
	    end
	 end
      end
      local url=cmd:url():gsub("[^/]$","")
      cmd:sendredirect(url)
   end

   local function upload(_ENV,rel,isPost)
      authorize(_ENV, rel, "PUT")
      emitHtmlHeader(_ENV,cmd,rel,"Upload File")
      cmd:write("<p>Upload a file to the ",
		rel,
		" directory.</p><form method='post' enctype='multipart/form-data'><p> File: <input type='file' size='40' name='file'/></p><input type='Submit' value='Upload file'/></form>")
      emitHtmlFooter(cmd)
   end

   local function ctxmenu(_ENV)
      response:sendredirect(ctxmuri)
   end

   local function getlock(_ENV,rel)
      local owner,time
      local name = cmd:data("name")
      pn=rel..name
      if dav:lockmgr(pn) then
	 owner,time=getLockOwner(_ENV,pn)
      else
	 local st = io:stat(pn)
	 if st and st.isdir then
	    name=name:match"([^/]+)/$"
	    if name then
	       pn=rel..name
	       if dav:lockmgr(pn) then
		  owner,time=getLockOwner(_ENV,pn)
	       end
	    end
	 end
      end
      if owner then
	 cmd:json{owner=owner,time=time}
      end
      cmd:json{notlocked=true}
   end

   local function getlocks(_ENV,rel)
      local files={}
      for n,v in request:datapairs() do
	 if n=="n" then
	    local name=rel..v
	    local st = io:stat(name)
	    if st and not st.isdir then
	       tinsert(files, {n=v,l=dav:lockmgr(name) and getLockOwner(_ENV,name) or false})
	    end
	 end
      end
      cmd:json{files=files}
   end

   local function lock(_ENV,rel)
      local time=tonumber(cmd:data"time" or 0)
      local tnow=os.time()
      if time and time > tnow then
	 for n,v in request:datapairs() do
	    if n=="n" then
	       local name=rel..v
	       local st = io:stat(name)
	       if st and not st.isdir and not dav:lockmgr(name) then
		  authorize(_ENV,name,"PUT")
		  dav:lockmgr(name,cmd,time - tnow)
	       end
	    end
	 end
      end
      cmd:json{ok=true}
   end

   local function unlock(_ENV,rel)
      for n,v in request:datapairs() do
	 if n=="n" then
	    local name=rel..v
	    if dav:lockmgr(name) then
	       authorize(_ENV,name,"PUT")
	       dav:lockmgr(name,false)
	    end
	 end
      end
      cmd:json{ok=true}
   end


   local dircmd={
      helpuri=dohelpuri,
      sesuri=sessionuri,
      ls=ls,
      lj=lj,
      mkdir=mkdir,
      mv=mv,
      mkdirt=function(_ENV,rel,isPost) mkdir(_ENV,rel,isPost,true) end,
      rm=remove,
      rmt=function(_ENV,rel,isPost) remove(_ENV,rel,isPost,true) end,
      upload=upload,
      ctxmenu=ctxmenu,
      getlock=getlock,
      getlocks=getlocks,
      unlock=unlock,
      lock=lock,
   }

   local function doDir(_ENV,rel,isPost)
      local c = cmd:data("cmd")
      local func = dircmd[(c or "ls")]
      if func then return func(_ENV,rel,isPost) end
      cmd:senderror(400,fmt("Unknown command: %s",xssfilt(c)))
   end

   local function startUpload(_ENV,up)
      filename=up:url()..up:name()
      cmd=up
      local fn=up:name()
      authorize(_ENV, fn, "PUT")
      checklock(_ENV,fn)
   end

   local function uploadCompleted(_ENV,up)
      url=up:url()
      cmd=up:response()
      txtrsp=true
      asyncSendresp(_ENV,nil,true)
   end

   local function uploadFailed(_ENV,up,emsg,extmsg)
      url=filename or up:url()
      cmd=up:response()
      asyncSendresp(_ENV,fmt("Uploading %s failed",url),false,emsg,extmsg)
   end

   local function PUT(_ENV,rel)
      authorize(_ENV, rel, "PUT")
      checklock(_ENV,rel)
      local env={rel=rel,davbut=davbut,helpdiv=helpdiv}
      if cmd:header"x-requested-with" then
	 env.jsonrsp=true
      else
	 env.txtrsp=txtrsp
      end
      env.dav=dav
      uploader(cmd,rel,startUpload,uploadCompleted,uploadFailed,env)
   end

   local function HEAD(_ENV,rel)
      authorize(_ENV, rel, "GET")
      local st = io:stat(rel)
      if not st then
	 cmd:senderror(404)
	 cmd:abort()
      end
      cmd:setcontentlength(st.isdir and 0 or st.size)
      if st.isdir then
	 cmd:setheader("BaIsDir","true")
      else
	 cmd:setcontenttype(ba.mime(rel:match("%.(%w+)$") or "bin"))
      end
      --Simulate a HttpResRdr response, which is used by the NetIo
      cmd:setheader("HttpResMgr","V2.1")
      cmd:setheader("Etag", fmt("%04X",st.mtime))
   end

   local function GET(_ENV,rel)
      local st = io:stat(rel)
      if not st then
	 authorize(_ENV, rel, "GET")
	 sendresp(_ENV,fmt("Resource %s",xssfilt(rel)),false,"notfound")
      end
      if st.isdir then
	 return doDir(_ENV,rel,false)
      end
      authorize(_ENV, rel, "GET")
      if cmd:data"download" then
	 -- Strip path and escape "
	 local name = match(rel,"[^/]*$"):gsub('"','\\"')
	 cmd:setheader("Content-Disposition",
		       fmt('attachment; filename="%s"',name))
	 cmd:setcontenttype"multipart/form-data"
      end
      return resrdr:service(cmd,rel,true) -- Delegate to resrdr (HttpResRdr)
   end

   local function POST(_ENV,rel)
      if cmd:header("Content-Type"):find("multipart/form-data",1,true) then
	 return PUT(_ENV,rel)
      end
      return doDir(_ENV,rel,true)
   end

   local serviceMethods={
      HEAD=HEAD,
      GET=GET,
      POST=POST,
      DELETE=DELETE,
      PUT=PUT
   }

   local function service(_ENV,rel,session)
      cmd=request
      _ENV.davbut=hasSesUri
      _ENV.helpdiv=helpdiv
      _ENV.dav=dav
      local ua,site = request:header"User-Agent",request:header"Sec-Fetch-Site"
      if site and "cross-site" == site then sendresp(_ENV,"Access denied",false,"") end
      local func=serviceMethods[request:method()]
      if func then
	 if ua and ua:find("Mozilla",1,true) then -- Assume WFM client
	    if not session then authenticate(request,rel) end
	    return func(_ENV,rel)
	 end
      end
      if func ~= POST then
	 if dav:service(cmd,rel) then return end -- Accepted
      end
      if func then
	 if not session then authenticate(request,rel) end
	 return func(_ENV,rel)
      end
      return false
   end

   local function authService(_ENV,rel)
      local s
      if not request:user() then
	 local p
	 s,p=ba.session(request,rel,true)
	 if s then
	    s:maxinactiveinterval(sesTmo)
	    rel=p
	 elseif manageMicrosoftClient(request, rel) then
	    return
	 end
      end
      return service(_ENV,rel,s)
   end

   resrdr=ba.create.resrdr(name,priority,io)
   resrdr:setfunc(service)
   dav=ba.create.dav(name,priority,io,lockdir,maxuploads,maxlocks)

   local function setService(filterfunc)
      hasSesUri = hasAuth and sesTmo and true or false
      if filterfunc then
	 _G.assert(type(filterfunc) == "function")
	 if hasSesUri then
	    local orgservice=service
	    service=
	       function(_ENV,rel,s)
		  return orgservice(_ENV,filterfunc(_ENV,rel,s))
	       end
	    resrdr:setfunc(authService)
	 else
	    local function filtserv(_ENV,rel)
	       return service(_ENV,filterfunc(_ENV,rel))
	    end
	    resrdr:setfunc(filtserv)
	 end
      else
	 resrdr:setfunc(hasSesUri and authService or service)
      end
   end

   local function setauth(authenticator, authorizer)
      local function _authenticate(cmd,rel)
	 if not authenticator:authenticate(cmd,rel) then
	    cmd:abort()
	 end
      end
      local function _authorize(_ENV,rel,method)
	 if not authorizer:authorize(cmd,method,rel) then
	    if #rel == 0 then rel="root" end
	    -- If cmd is a 'upload' type
	    if not cmd.write then cmd=cmd:response() end
	    if isAjaxReq(_ENV) then
	       cmd:json{err="noaccess",emsg=fmt("You do not have %s access to %s",method,rel)}
	    end
	    cmd:setstatus(403)
	    if txtrsp then
	       cmd:write("You do not have access to ",rel,".")
	    else
	       emitHtmlHeader(_ENV,cmd,rel,"Access denied")
	       cmd:write("<h1>Access denied</h1><p>You do not have access to ",rel,".</p>")
	       cmd:write"<p>Press the back button to continue.</p>"
	       emitHtmlFooter(cmd)
	    end
	    cmd:abort()
	 end
      end
      authenticate = authenticator and _authenticate or doNothing
      authorize = authorizer and _authorize or doNothing
      hasAuth = (authenticator or authorizer) and true or false
      dav:setauth(authenticator,authorizer)
      setService()
   end

   local function configure(t)
      if not t.tmo or t.tmo == 0 then
	 sesTmo=nil
      else
	 sesTmo=t.tmo
      end
      helpuri=t.helpuri
      ctxmuri=t.ctxmuri or ctxmuri
      if t.dircmd then
	 for k,v in _G.pairs(t.dircmd) do dircmd[k]=v end
      end
      helpdiv=createHelpDiv(t.logouturi,t.helpuri)
      setService(t.filterservice)
      return {authorize=authorize,io=io}
   end

   return resrdr,setauth,configure
end



local wfs={}
wfs.__index=wfs
_G.setmetatable(wfs,_G.getmetatable(ba.create.dir()))
function wfs:setauth(authenticator, authorizer)
   self.dir:setauth(authenticator, authorizer)
   self.auth(authenticator, authorizer)
end

function wfs:configure(cfg)
   return self.cfg(cfg)
end

function wfs:service(req,rel)
   self.dir:service(req,rel)
end

local function parseArgs(argv)
   local name=nil
   local priority=0
   local io
   lockdir=nil
   local maxuploads=5
   local maxlocks=20
   local argIx=1
   if "string" == type(argv[argIx]) then
      name=argv[argIx]
      argIx=argIx+1
   end
   if "number" == type(argv[argIx]) then
      priority=argv[argIx]
      argIx=argIx+1
   end
   io=argv[argIx]
   argIx=argIx+1
   if "string" == type(argv[argIx]) then
      lockdir=argv[argIx]
      argIx=argIx+1
   end
   if "number" == type(argv[argIx]) then
      maxuploads=argv[argIx]
      maxlocks=argv[argIx+1]
   end
   return name,priority,io,lockdir,maxuploads,maxlocks
end

function ba.create.wfs(...)
   local dir,setauth,configure=newWFS(parseArgs{...})
   return _G.setmetatable({dir=dir,auth=setauth,cfg=configure}, wfs)
end

return _ENV
