function [loc,info]=decodeh5ToLoc(file)
[~,~,ext]=fileparts(file);
switch ext
    case '.h5'
        [locs,info]=loadh5(file);
    case '.csv'
        [locs,info]=loadcsv(file);
end
% locData=interfaces.LocalizationData;
if strcmp(info.unit,'px')
    pix2nm=info.px_size;
else
    pix2nm=[1 1];
end
info.pix2nm=pix2nm;
% filenumber=obj.locData.files.filenumberEnd+1;
zd=zeros(size(locs.x),'single');

loc.ynm=single(locs.x*pix2nm(1));
loc.xnm=single(locs.y*pix2nm(2));
loc.znm=single(locs.z);
loc.phot=single(locs.phot);
loc.frame=double(locs.frame_ix+1);
loc.prob=single(locs.prob);
loc.LLrel=single(locs.prob)-1; %to fit in the -inf to zero range...

% loc.filenumber=zd+1;
loc.channel=zd;

if ~info.thin
    loc.ynmerr=single(locs.x_sig*pix2nm(1));
    loc.xnmerr=single(locs.y_sig*pix2nm(2));
    loc.locprecznm=single(locs.z_sig);
    loc.bg=single(locs.bg);
    loc.phot_err=single(locs.phot_sig);
    loc.locprecnm=(loc.xnmerr+loc.ynmerr)/2;
else
    loc.bg=zd;
    loc.locprecznm=mean(pix2nm)./sqrt(locs.phot)*3;
    loc.locprecnm=mean(pix2nm)./sqrt(locs.phot);
end
end

function [locs,io]=loadh5(file)
info=h5info(file);
io.version=info.Groups(2).Attributes.Value;
io.unit=info.Groups(3).Attributes(1).Value;
io.px_size=info.Groups(3).Attributes(2).Value;
for k=1:length(info.Groups(1).Datasets) 
    locs.(info.Groups(1).Datasets(k).Name)=h5read(file,['/data/' info.Groups(1).Datasets(k).Name]);
end
locs.x(:,1)=locs.xyz(1,:);
locs.y(:,1)=locs.xyz(2,:);
locs.z(:,1)=locs.xyz(3,:);

io.thin=true;
if ~isempty(locs.xyz_sig)
    io.thin=false;
    locs.x_sig(:,1)=locs.xyz_sig(1,:);
    locs.y_sig(:,1)=locs.xyz_sig(2,:);
    locs.z_sig(:,1)=locs.xyz_sig(3,:);
end

if ~isempty(locs.xyz_cr)
    locs.x_cr(:,1)=locs.xyz_cr(1,:);
    locs.y_cr(:,1)=locs.xyz_cr(2,:);
    locs.z_cr(:,1)=locs.xyz_cr(3,:);
end

end

function [locso,io]=loadcsv(file)
locs=readtable(file,'NumHeaderLines',3);
fid=fopen(file);
fgetl(fid);
l2=fgetl(fid);
l3=fgetl(fid);
fclose(fid);
io.version=sscanf(l2,'# {%*s "%s}');
io.version(end-2:end)='';
io.unit=sscanf(l3,'# {%*s "%s}');
io.unit(end-1:end)=[];
io.px_size=sscanf(l3,'# {%*s %*s %*s [%f, %f }');

varnames=locs.Properties.VariableNames;
for k=1:length(varnames)
    if isnan(locs.(varnames{k})(1))
        if all(isnan(locs.(varnames{k})))
            continue
        end
    end
    locso.(varnames{k})=locs.(varnames{k});
end

% locs=table2struct(locs);
io.thin=false;
if ~isfield(locso, 'x_sig') || all(isnan(locs.x_sig))
    io.thin=true;
end

end