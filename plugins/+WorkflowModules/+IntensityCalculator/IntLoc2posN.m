classdef IntLoc2posN<interfaces.WorkflowModule
%     calculates pixel postions in tiff images from localization positions (nm)
    properties
        filestruc;
        locs
        roi
        transformation=[];
        samechip=true;
    end
    methods
        function obj=IntLoc2posN(varargin)
            obj@interfaces.WorkflowModule(varargin{:});
        end
        function pard=guidef(obj)
            pard=guidef;
        end
        function initGui(obj)
            initGui@interfaces.WorkflowModule(obj);
        end
        function prerun(obj,data,p)
            global intLoc2pos_ind2 intLoc2pos_locframes;
            intLoc2pos_ind2=1;
            obj.locData.sort('frame');
            % filter again?
            p=obj.getAllParameters;
            if isempty(obj.transformation)
                transform=loadtransformation(obj,p.Tfile);
            else
                transform=obj.transformation;
            end
            obj.locs=obj.locData.getloc({'frame','xnm','ynm','znm','PSFxnm','phot','bg','groupindex','numberInGroup','filenumber'});
            cpix=obj.locData.files.file(obj.locs.filenumber(1)).info.cam_pixelsize_um*1000;

            x=double(obj.locs.xnm)/cpix(1);  %in pixels
            y=double(obj.locs.ynm)/cpix(end);
            obj.locs.xA=x;obj.locs.yA=y;
            postotarget=transform.transformToTarget(2,horzcat(x,y));
            if obj.samechip
                obj.locs.xB=x;obj.locs.yB=y;   
                indref=transform.getPart(1,horzcat(x,y));
                indtarget=transform.getPart(2,horzcat(x,y));

             %XXXXXXXXXXXX
             %if in two separate files: only consider correct file. Now:
             %only load reference file. Make sure that then target
             %positions are not put back.
             
%              make xref, xtar: all localizations put into one or other
%              channel. Below just assign theh right one, and the other to
%              xB.
                postoreference=transform.transformToReference(2,horzcat(x,y));
                if p.transformtotarget    
                        obj.locs.xA(indref)=postotarget(indref,1);obj.locs.yA(indref)=postotarget(indref,2);
                        obj.locs.xB(indtarget)=postoreference(indtarget,1);obj.locs.yB(indtarget)=postoreference(indtarget,2);
                else

                        obj.locs.xA(indtarget)=postoreference(indtarget,1);obj.locs.yA(indtarget)=postoreference(indtarget,2);
                        obj.locs.xB(indref)=postotarget(indref,1);obj.locs.yB(indref)=postotarget(indref,2);
                end
            else
                obj.locs.xB=[];obj.locs.yB=[]; 
                if p.transformtotarget  
                    obj.locs.xA=postotarget(:,1);obj.locs.yA=postotarget(:,2);
                end
            end

            if ~isempty(obj.locs.znm)
                    d=0.42;
                    g=-0.2;
                    sx0=1.1;
                    obj.locs.PSFxpix=sigmafromz_simple(obj.locs.znm/1000,[d -g sx0]);
                    obj.locs.PSFypix=sigmafromz_simple(obj.locs.znm/1000,[d g sx0]);
            else
                if  p.transformtotarget
%                     cpix=transform.cam_pixnm{1}(1); %nor target cam pix???
                    try
                        cpix=transform.cam_pixnm{2}(1);
                    catch error
                        cpix=obj.locData.files.file(1).info.cam_pixelsize_um*1000;
                    end
                end
                obj.locs.PSFxpix=double(obj.locs.PSFxnm/cpix(1));
                obj.locs.PSFypix=obj.locs.PSFxpix;
            end
            intLoc2pos_locframes=obj.locs.frame;
            obj.roi=obj.getPar('loc_fileinfo').roi;
        end
        function nodatout=run(obj,data,p)
            nodatout=[];
            global intLoc2pos_ind2 intLoc2pos_locframes

                if ~data.eof
                    lf=length(obj.locs.xA);
                    frame=data.frame;
                    %find indices for same frame
                    ind1=intLoc2pos_ind2;
                    while ind1>0&&intLoc2pos_locframes(ind1)<frame && ind1<lf
                        ind1=ind1+1;
                    end
                    ind1=min(ind1,lf);
                    intLoc2pos_ind2=ind1;
                    if ~(intLoc2pos_locframes(intLoc2pos_ind2)==frame) %no localizatiaon in frame
                          datout=data;%.copy;
                         datout.data=struct('xpix',[]);%.set(maxout);
                        return
                    end
                    while intLoc2pos_ind2<=lf&&intLoc2pos_locframes(intLoc2pos_ind2)==frame
                        intLoc2pos_ind2=intLoc2pos_ind2+1;
                    end
                    intLoc2pos_ind2=intLoc2pos_ind2-1;

                   xrel=(obj.locs.xA(ind1:intLoc2pos_ind2)-obj.roi(1));
                   yrel=(obj.locs.yA(ind1:intLoc2pos_ind2)-obj.roi(2));



                  % do the same output for xB, the other one. Mabe with swithc if to put out other channel, if not, only one. Tehn we can use the same WF for all.  
                   maxout.xpix=round(xrel);
                   maxout.ypix=round(yrel);
                   maxout.frame=frame+0*maxout.ypix;
                   maxout.dx=xrel-maxout.xpix;
                   maxout.dy=yrel-maxout.ypix;
                   maxout.PSFxpix=obj.locs.PSFxpix(ind1:intLoc2pos_ind2);
                   maxout.PSFypix=(obj.locs.PSFypix(ind1:intLoc2pos_ind2));
                   maxout.groupindex=obj.locs.groupindex(ind1:intLoc2pos_ind2);
                   maxout.numberInGroup=obj.locs.numberInGroup(ind1:intLoc2pos_ind2);
                   maxout.phot=obj.locs.phot(ind1:intLoc2pos_ind2);
                   maxout.bg=obj.locs.bg(ind1:intLoc2pos_ind2);
                   maxout.ind=ind1:intLoc2pos_ind2;
                   if ~isempty(obj.locs.znm)
                       maxout.znm=obj.locs.znm(ind1:intLoc2pos_ind2);
                   end
                   datout=data;%.copy;
                   datout.data=maxout;%.set(maxout);
                   obj.output(datout,1); 
                    
                   if obj.samechip
                       xrelB=(obj.locs.xB(ind1:intLoc2pos_ind2)-obj.roi(1));
                       yrelB=(obj.locs.yB(ind1:intLoc2pos_ind2)-obj.roi(2));
%                        maxoutA=maxout; %for testing
                       %output second channel
                       maxout.xpix=round(xrelB);
                       maxout.ypix=round(yrelB);
                       maxout.dx=xrelB-maxout.xpix;
                       maxout.dy=yrelB-maxout.ypix;
                       datout=data;%.copy;
                       datout.data=maxout;%.set(maxout);
                       obj.output(datout,2);   
                   end
                else
                   datout=data;
                    datout.data=struct('xpix',[]);
                    datout.eof=true;
                    obj.output(datout,1); 
                    obj.output(datout,2); 
                end
                

        end
    end
end

% function [loc,locr]=nm2pixLoc(x,y,pixelsize,roi)
% loc.x=(x/pixelsize(1))-roi(1);
% loc.y=(y/pixelsize(2))-roi(2);
% locr.x=round(loc.x);
% locr.y=round(loc.y);
% end


function pard=guidef
pard.Tfile.object=struct('Style','edit','String','Tfile');
pard.Tfile.position=[1,1];
pard.Tfile.Width=1.3;
pard.transformtotarget.object=struct('Style','checkbox','String','transform');
pard.transformtotarget.position=[1,2.3];
pard.transformtotarget.Width=.7;
% pard.pixcam.object=struct('Style','edit','String','138');
% pard.pixcam.position=[2,1];
% pard.PSFxnm.object=struct('Style','edit','String','138');
% pard.PSFxnm.position=[2,1];
pard.plugininfo.type='WorkflowModule';
pard.plugininfo.description='calculates pixel postions in tiff images from localization positions (nm)';
end

function PSFx=sigmafromz_simple(z,p)%[d g sx0]);
    PSFx=p(3).*sqrt(1+(z-p(2)).^2./p(1).^2);
end


function s=sigmafromz(par,z,B0)
par=real(par);
% parx= [d sx0 Ax Bx g mp]
s0=par(2);d=par(1);A=par(3);B=par(4)*B0;g=par(5);mp=par(6);

% s=s0*sqrt(1+(z-g+mp).^2/d^2);
s=s0*sqrt(1+(z-g+mp).^2/d^2+A*(z-g+mp).^3/d^3+B*(z-g+mp).^4/d^4);
s=real(s);
end