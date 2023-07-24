local a=ba.b64urlencode;local function b(c)return a(ba.json.encode(c))end;local function d(e)local f,g=ba.crypto.keyparams(e)if not f then error"Use ECC key"end;local h={kty="EC",crv="P-256",x=a(f),y=a(g)}return{alg='ES256',typ="JWT",jwk=h}end;local function i(e,j,k)k=k or{alg="ES256",typ="JWT"}local l,m;local n=b(k)j=type(j)=="string"and j or b(j)local o=n.."."..j;if k.alg=="ES256"then local p=ba.crypto.hash"sha256"(o)(true)p,m=ba.crypto.sign(p,e)if not p then return nil,m end;local q,r=ba.crypto.sigparams(p)l=a(q..r)elseif k.alg=="HS256"then l=a(ba.crypto.hash("hmac","sha256",e)(o)(true))else error"Non supported alg"end;return{protected=n,payload=j,signature=l}end;local function s(e,j,k)local c,m=i(e,j,k)if c then return string.format("%s.%s.%s",c.protected,c.payload,c.signature)end;return nil,m end;return{jwkh=d,sign=i,scomp=s}