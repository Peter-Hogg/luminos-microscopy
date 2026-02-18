classdef Sutter_MP285A < Linear_Controller
    properties (Transient)
        limits
        % speed
        mode
        axes
        serial_com internal.Serialport
        COMPORT string
    end
    properties (SetAccess = private, SetObservable)
        microstep_size_xy
        microstep_size_z
        xlims_um = [-12500,12500];
        ylims_um = [-12500,12500];
        zlims_um = [-10300,18175];
    end
    properties
        %current_position
        pos % {x, y, z}
    end

    methods
        function obj = Sutter_MP285A(Initializers)
            obj@Linear_Controller(Initializers)
            obj.microstep_size_xy = 40e-3; %step size in microns
            obj.microstep_size_z = 30e-3;
            obj.COMPORT = obj.Initializer.COMPORT;
            obj.Configure_Controller();
        end
        
        function Configure_Controller(obj)
            obj.serial_com = serialport(obj.COMPORT, 9600, 'Timeout', obj.port_timeout);
            configureTerminator(obj.serial_com, "CR");
            set(obj.serial_com, 'DataBits', 8);
            set(obj.serial_com, 'FlowControl', 'hardware');
            set(obj.serial_com, 'Parity', 'none');
            set(obj.serial_com, 'StopBits', 1);
            set(obj.serial_com, 'Timeout', 10);
        end
        
        function success = Move_To_Position(obj, position)
            x = min(max(position(1),obj.xlims_um(1)),obj.xlims_um(2));
            y = min(max(position(2),obj.ylims_um(1)),obj.ylims_um(2));
            z = min(max(position(3),obj.zlims_um(1)),obj.zlims_um(2));
            flush(obj.serial_com);
            obj.serial_com.write(char(109), 'uint8');
            obj.serial_com.write(int32(round(x/obj.microstep_size_xy)), 'int32');
            obj.serial_com.write(int32(round(y/obj.microstep_size_xy)), 'int32');
            obj.serial_com.write(int32(round(z/obj.microstep_size_z)), 'int32');
            obj.serial_com.write(char(13),'uint8'); %message terminator
            tic
            msg = obj.serial_com.readline();
            move_time = toc();
            success = 1; % TODO: read msg to see if successful (but not too important)
        end
        
        function Step_Fixed(obj, dim, distance_um)
            flush(obj.serial_com);
            obj.Update_Current_Position_Microns();
            if dim == 1
                obj.Move_To_Position([obj.pos.x + distance_um, obj.pos.y, obj.pos.z]);
            elseif dim == 2
                obj.Move_To_Position([obj.pos.x, obj.pos.y + distance_um, obj.pos.z]);
            elseif dim == 3
                obj.Move_To_Position([obj.pos.x, obj.pos.y, obj.pos.z + distance_um]);
            end
        end
        
        
        function pos = get.pos(obj)
            pos = obj.Get_Current_Position_Microns();
            obj.pos = pos;
        end
        
        function pos = Get_Current_Position_Microns(obj)
            flush(obj.serial_com);
            obj.serial_com.writeline('c');
            
            %Cannot use readline as the numeric byte values to be read can
            %take the value '10', which is read as a CR and terminates the
            %readline call. Must instead read the desired number of bytes
            %using read()
            res = uint8(obj.serial_com.read(13, 'uint8'));
            data = typecast(res(1:end-1), 'int32');
            if isempty(data)
                error("Attempt to get current Sutter Stage Position failed: Serial port timed out.")
            end
            pos.x = double(data(1)) * obj.microstep_size_xy;
            pos.y = double(data(2)) * obj.microstep_size_xy;
            pos.z = double(data(3)) * obj.microstep_size_z;
        end

        function Interrupt_Move(obj)
            flush(obj.serial_com);
            obj.serial_com.write(char(3),'uint8');
            msg = obj.serial_com.readline();
            if msg == ""
                disp("Abort Move Sutter MP285A: No move in progress");
            elseif msg == "="
                    warning("Abort Move Sutter MP285A Movement in progress:...aborted");
            else
                warning("unrecognized return message to abort command");
            end
        end

        function Reset_Controller(obj)
            flush(obj.serial_com);
            obj.serial_com.writeline('r');
            msg = obj.serial_com.readline();
        end

        function status = Get_Status(obj)
            flush(obj.serial_com);
            obj.serial_com.writeline('s');
            res = uint8(obj.serial_com.read(33,'uint8'));
            
            status.flags = res(1);
            status.axis_directions = res(2:4);
            status.microsteps_per_roe_click = typecast(res(5:6),'uint16');
            status.user_offset = typecast(res(7:8),'uint16');
            status.user_range = typecast(res(9:10),'uint16');
            status.microsteps_per_pulse = typecast(res(11:12),'uint16');
            status.pulse_speed_microsteps_per_s = typecast(res(13:14),'uint16');
            status.input_device_type = res(15);
            status.flags_2 = res(16);
            status.jumpspd = typecast(res(17:18),'uint16');
            status.highspd = typecast(res(19:20),'uint16');
            status.deadzone = typecast(res(21:22),'uint16');
            status.watch_dog = typecast(res(23:24),'uint16');
            %For MP-285A, 25:26 and 27:28 are duplicates;
            status.microns_per_microstep = double(typecast(res(27:28),'uint16'))/10000;
            xspeed = typecast(res(29:30),'uint16');
            res_bit = bitget(xspeed,15);
            if res_bit
                status.resolution = 'high';
                status.speed = xspeed - 0x8000;
            else
                status.resolution = 'low';
                status.speed = xspeed;
            end
            status.firmware_version = double(typecast(res(31:32),'uint16'))/100;
        end
    end
end
