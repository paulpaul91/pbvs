function [t_out, s_out] = simulation_3d(trajhandle, controlhandle)
% NOTE: This srcipt will not run as expected unless you fill in proper
% code in trajhandle and controlhandle
% You should not modify any part of this script except for the
% visualization part
%
% ***************** QUADROTOR SIMULATION *****************

% *********** YOU SHOULDN'T NEED TO CHANGE ANYTHING BELOW **********

addpath('utils');

% real-time
real_time = true;

% max time
max_time = 60;

% parameters for simulation
params = sys_params;

%% **************************** FIGURES *****************************
disp('Initializing figures...');
h_fig = figure;
h_3d = gca;
axis equal
grid on
view(3);
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]')
quadcolors = lines(1);

set(gcf,'Renderer','OpenGL')

%% *********************** INITIAL CONDITIONS ***********************
disp('Setting initial conditions...');
tstep    = 0.01*1; % this determines the time step at which the solution is given
cstep    = 0.05*1; % image capture time interval
max_iteration = max_time/cstep; % max iterationation
nstep    = cstep/tstep;
time     = 0; % current time
err = []; % runtime errors

% Get start and stop position
des_start = trajhandle(0, []);
des_stop  = trajhandle(inf, []);
stop_pos  = des_stop.pos;
x0    = init_state(des_start.pos, 0);
xtraj = zeros(max_iteration*nstep, length(x0));
ttraj = zeros(max_iteration*nstep, 1);

x       = x0;        % state

pos_tol = 0.01;
vel_tol = 0.01;

%% ************************* RUN SIMULATION *************************
disp('Simulation Running....');
% Main loop
for iteration = 1:max_iteration

    timeint = time:tstep:time+cstep;

    tic;
global flag;

flag = iteration;
    % Initialize quad plot
    if iteration == 1
        QP = QuadPlot(1, x0, 0.1, 0.04, quadcolors(1,:), max_iteration, h_3d);
        current_state = stateToQd(x);
        fprintf('Time passed: %d',time);
        desired_state = trajhandle(time, current_state);
        QP.UpdateQuadPlot(x, [desired_state.pos; desired_state.vel], time);
        h_title = title(sprintf('iterationation: %d, time: %4.2f', iteration, time));
    end

    % Run simulation
    
    %open rave modification START
    global accel;
    accel = openraveConnect(time,cstep,current_state);
    %open rave modification END
    
    initial_state=current_state;
    [tsave, xsave] = ode45(@(t,s) quadEOM(t, s, controlhandle, trajhandle, params,initial_state), timeint, x);
%   [tsave, xsave] = ode23t(@(t,s) quadEOM(t, s, controlhandle, trajhandle, params,initial_state), timeint, x);
    x    = xsave(end, :)';
%     display(x);
%     display(desired_state.pos);
%     display(desired_state.vel);
%     display(desired_state.acc);
%     display(desired_state.yaw);
    
    % Save to traj
    xtraj((iteration-1)*nstep+1:iteration*nstep,:) = xsave(1:end-1,:);
    ttraj((iteration-1)*nstep+1:iteration*nstep) = tsave(1:end-1);

    % Update quad plot
    current_state = stateToQd(x);
%     display(current_state.pos);
%     display(current_state.vel);
%     display(current_state.rot);
%     display(current_state.omega);
    dist_error= sqrt(sum((desired_state.pos-current_state.pos).^2));
    display(dist_error);
%     if(dist_error<0.05)
    desired_state = trajhandle(time + cstep, current_state);
%     display(desired_state.pos);
%     end
    
    
    QP.UpdateQuadPlot(x, [desired_state.pos; desired_state.vel], time + cstep);
    set(h_title, 'String', sprintf('iterationation: %d, time: %4.2f', iteration, time + cstep))

    time = time + cstep; % Update simulation time
    flag =0;
    t = toc;
    % Check to make sure ode45 is not timing out
%     if(t> cstep*50)
%         err = 'Ode45 Unstable';
%         break;
%     end

    % Pause to make real-time
    if real_time && (t < cstep)
        pause(cstep - t);
    end

    % Check termination criterationia
    if terminate_check(x, time, stop_pos, pos_tol, vel_tol, max_time)
        break
    end
end

%% ************************* POST PROCESSING *************************
% Truncate xtraj and ttraj
xtraj = xtraj(1:iteration*nstep,:);
ttraj = ttraj(1:iteration*nstep);

% Truncate saved variables
QP.TruncateHist();

% Plot position
h_pos = figure('Name', ['Quad position']);
plot_state(h_pos, QP.state_hist(1:3,:), QP.time_hist, 'pos', 'vic');
plot_state(h_pos, QP.state_des_hist(1:3,:), QP.time_hist, 'pos', 'des');
% Plot velocity
h_vel = figure('Name', ['Quad velocity']);
plot_state(h_vel, QP.state_hist(4:6,:), QP.time_hist, 'vel', 'vic');
plot_state(h_vel, QP.state_des_hist(4:6,:), QP.time_hist, 'vel', 'des');

if(~isempty(err))
    error(err);
end

disp('finished.')

t_out = ttraj;
s_out = xtraj;

end