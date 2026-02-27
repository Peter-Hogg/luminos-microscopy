function Camera_Snap(app, experimentName, options)
arguments
    app
    experimentName
    options.devicename = []
    options.show_date = true
end
cam = app.getDevice('Camera', 'name', options.devicename);
cam.Get_ROI();
snap = CL_RefImage();
% Get all available DMD devices
dmd = app.getDevice('DMD');

if ~isempty(dmd)
    snap.tform(length(dmd)).tform = affine2d();
    for i = 1:length(dmd)
        snap.tform(i).name = dmd(i).name;
        snap.tform(i).tform = dmd(i).tform;
    end
else
    % Handle case where no DMDs are found
    snap.tform = [];
end


snap.bin = cam.bin;
snap.img = cam.Snap();

% Reshape if depending on binning - DI 6/24
sizes_bin = size(snap.img)/snap.bin;
snap.img = reshape(snap.img(1:ceil(sizes_bin(1)/snap.bin),:)',sizes_bin(2),ceil(sizes_bin(1)/snap.bin)*snap.bin)';
extra_lines = ceil(sizes_bin(1)/snap.bin)*snap.bin - sizes_bin(1);
snap.img = snap.img(1:end-extra_lines,:);
%figure; imagesc(snap.img); disp(size(snap.img));

snap.type = 'Camera';
snap.name = cam.name;
snap.ref2d.ImageSize = size(snap.img);
snap.ref2d.XWorldLimits = double([cam.ROI(1), cam.ROI(1) + cam.ROI(2)]);
snap.ref2d.YWorldLimits = double([cam.ROI(3), cam.ROI(3) + cam.ROI(4)]);
snap.xdata = cam.ROI(1) + 1:cam.ROI(1) + cam.ROI(2);
snap.ydata = cam.ROI(3) + 1:cam.ROI(3) + cam.ROI(4);
snap.timestamp = datetime("now");
if options.show_date
    ds = datestr(now, 'HHMMSS');
else
    ds = '';
end

snapfolder = fullfile(app.datafolder, 'Snaps');
if ~exist(snapfolder, 'dir')
    mkdir(snapfolder)
end
snapimfile = fullfile(snapfolder, strcat(ds, experimentName, '.tiff'));
snapdatfile = fullfile(snapfolder, strcat(ds, experimentName, '.mat'));
pause(.01);
drawnow;
% --- Camera ---
metadata.timestamp      = datestr(snap.timestamp, 'yyyy-mm-dd HH:MM:SS');
metadata.experiment     = experimentName;
metadata.camera         = snap.name;
metadata.binning        = snap.bin;
metadata.roi_x          = cam.ROI(1);
metadata.roi_y          = cam.ROI(3);
metadata.roi_width      = cam.ROI(2);
metadata.roi_height     = cam.ROI(4);
metadata.image_width    = size(snap.img, 2);
metadata.image_height   = size(snap.img, 1);
metadata.exposure_s     = cam.exposureTimeSeconds;
metadata.x_world_limits = snap.ref2d.XWorldLimits;
metadata.y_world_limits = snap.ref2d.YWorldLimits;

% --- Lasers / Light Sources ---
%lasers = app.getDevice('Light_Source');
%if ~isempty(lasers)
%    laser_info = struct();
%    for i = 1:length(lasers)
%        entry = struct();
%        entry.name    = lasers(i).name;
%        % Try common property names - adjust to match your actual device class
%        if isprop(lasers(i), 'enabled');  entry.enabled = lasers(i).enabled;   end
%        if isprop(lasers(i), 'power');    entry.power   = lasers(i).power;     end
%        if isprop(lasers(i), 'wavelength'); entry.wavelength = lasers(i).wavelength; end
%        laser_info(i).laser = entry;
%    end
%    metadata.lasers = laser_info;
%end

% --- Shutters ---
%shutters = app.getDevice('Shutter');
%if ~isempty(shutters)
%    shutter_info = struct();
%    for i = 1:length(shutters)
%        entry = struct();
%        entry.name    = shutters(i).name;
%        if isprop(shutters(i), 'isOpen'); entry.is_open = shutters(i).isOpen; end
%        shutter_info(i).shutter = entry;
%    end
%    metadata.shutters = shutter_info;
%end

% --- Serialize and write TIFF ---
meta_json = jsonencode(metadata);

t = Tiff(snapimfile, 'w');
tagstruct.ImageLength       = size(snap.img, 1);
tagstruct.ImageWidth        = size(snap.img, 2);
tagstruct.Photometric       = Tiff.Photometric.MinIsBlack;
tagstruct.BitsPerSample     = 16;
tagstruct.SamplesPerPixel   = 1;
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Compression       = Tiff.Compression.None;
tagstruct.RowsPerStrip      = size(snap.img, 1);
tagstruct.ImageDescription  = meta_json;
t.setTag(tagstruct);
t.write(snap.img);
t.close();
save(snapdatfile, 'snap', '-v7.3');
Save_Snap_To_JS(app, snap.img, experimentName, ds);
end
