-- Small data-only JSON decoder. Never evaluates settings as Lua code.
local M={}
function M.decode(text)
 local i=1
 local parse
 local function skip() local _,e=text:find('^%s*',i);i=(e or i-1)+1 end
 local function string_value()
  i=i+1;local out={}
  while i<=#text do
   local c=text:sub(i,i);i=i+1
   if c=='"' then return table.concat(out) end
   if c=='\\' then
    local e=text:sub(i,i);i=i+1
    local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
    if e=='u' then
     local n=tonumber(text:sub(i,i+3),16);assert(n,'bad unicode');i=i+4
     if n>=0xD800 and n<=0xDBFF then
      assert(text:sub(i,i+1)=='\\u','missing surrogate');local low=tonumber(text:sub(i+2,i+5),16)
      assert(low and low>=0xDC00 and low<=0xDFFF,'bad surrogate');i=i+6;n=0x10000+(n-0xD800)*1024+low-0xDC00
     end
     out[#out+1]=utf8.char(n)
    else assert(escapes[e],'bad escape');out[#out+1]=escapes[e] end
   else assert(c:byte()>=32,'control character');out[#out+1]=c end
  end
  error('unterminated string')
 end
 parse=function(depth)
  assert(depth<40,'too deep');skip();local c=text:sub(i,i)
  if c=='"' then return string_value() end
  if c=='{' or c=='[' then
   local obj=c=='{';local close=obj and '}' or ']';i=i+1;skip();local result={}
   if text:sub(i,i)==close then i=i+1;return result end
   while true do
    local key=#result+1
    if obj then skip();assert(text:sub(i,i)=='"','expected key');key=string_value();skip();assert(text:sub(i,i)==':','expected colon');i=i+1 end
    result[key]=parse(depth+1);skip();c=text:sub(i,i);i=i+1
    if c==close then return result end
    assert(c==',','expected comma')
   end
  end
  for word,value in pairs({['true']=true,['false']=false}) do if text:sub(i,i+#word-1)==word then i=i+#word;return value end end
  if text:sub(i,i+3)=='null' then i=i+4;return nil end
  local number=text:match('^%-?%d+%.?%d*[eE]?[+-]?%d*',i);assert(number,'expected value')
  local value=tonumber(number);assert(value and value==value and math.abs(value)<math.huge,'bad number');i=i+#number;return value
 end
 local result=parse(0);skip();assert(i>#text,'trailing data');return result
end
return M
