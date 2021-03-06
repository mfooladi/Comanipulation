%% Reading data
x = dlmread('chest_striaght.txt',',',1, 0);
% x = dlmread('chest_obstacle.txt',',',1, 0);
dt = 0.003;
% remove unnecesessary data data 
a=1;
b=[1 -1];
y = filter(b,a,x);
I = y(:,1)>=1e-3;
x = x(I,:);
%dlmwrite('chest_obstacle_filtered.txt',x);
% smooth data
% a=1;
% b=[1/4 1/4 1/4 1/4];
% y = filter(b,a,x);
visualization = true;
%% Visualising data
if visualization
    close all
    figure(1)
    theta = atan2d(x(:,3)-x(:,6), x(:,2)-x(:,5));
    for i=2:4
        subplot(4,2,2*i-3)
        plot(x(:,1), x(:,i),'r-')
        hold on 
        plot(x(:,1), x(:,i+3),'b--')
        grid on
    end
    subplot(4,2,7)
    plot(x(:,1), theta,'r-')
    grid on

    subplot(1,2,2)
    plot(x(:,2), x(:,3),'r-')
    hold on
    plot(x(:,5), x(:,6),'b--')
    xlim([-1500 2500]);
    xlabel('X');
    ylabel('Y');
end
%% calculateing object position and angle 
theta = atan2(x(:,3)-x(:,6), x(:,2)-x(:,5));
x=[x(:,1) .5*(x(:,2)+x(:,5)) .5*(x(:,3)+x(:,6)) theta];
%% Splitting patterns
% patterns start and end timestamps, and pattern type number
tp=dlmread('chest_straight_patterns.txt');
% tp=dlmread('chest_obstacle_patterns.txt');
%  patterns data
num_patterns = size(tp,1);
patterns = cell(num_patterns, 2);
for i = 1:num_patterns
    % split the data
    I = (x(:,1) > tp(i,1)) & (x(:,1) < tp(i,2));
    tmp = x(I,:);
    tmp(:,1) = tmp(:,1) - tmp(1,1); 
    
    % apply kalman filter
    tmp = kalman3d(tmp);
    v_tmp = [tmp(:,1) tmp(:,5:7)];
    v_tmp = kalman3d(v_tmp);
    tmp = [tmp(:,1:4) v_tmp(:,2:7)]; % tmp = [time, x, xdot, xddot]
    
    % reduce the data size
    timespan = linspace(0,tmp(end,1),100);
    xq = interp1(tmp(:,1), tmp(:,2:end), timespan);
    xq(end,4:end)=0.*xq(end,4:end);
%     xf = simulate_force(tmp, dt);
%     xf = tmp(:,2:7); % xf = [x and xdot]
    xf = xq(:,1:6); % xf = [x and xdot]
    patterns{i,1} = xf;
    patterns{i,2} = tp(i,3);    
end





%% find x0 and xf
x0=[];
xf=[];
for i = 1:num_patterns
    if patterns{i,2} == 1
        x0 = [x0; patterns{i,1}(1,:)];
    else
        xf = [xf; patterns{i,1}(1,:)];
    end
end
x0 = mean(x0);
xf = mean(xf);
dlmwrite('config.txt',[x0; xf]);

%% fit gaussian proccess model
predictor_data = [];
response_data = [];
for i = 1:num_patterns
% for i = 1:1
    % predictors, xi = [x y theta xdot ydot thetadot pattern_no]
    pattern_no = patterns{i,2};
    xi = patterns{i,1};
%     xi = [xi(:,1:3)  ones(size(xi,1),1)*pattern_no];
    xi = [xi  ones(size(xi,1),1)*pattern_no];
    predictor_data = [predictor_data; xi];
    
    % responses = [x y theta xdot ydot thetadot pattern_no] at the next time step
    % find next values
    tmp = [xi(2:end,:); xi(end,:)];
%     tmp = [xi(6:end,:); xi(end-4:end,:)];
    response_data = [response_data; tmp];
end
num_Mdls = size(response_data,2);
gprMdls = cell(num_Mdls,1);
for i=1:num_Mdls
    gprMdls{i,1} = fitrgp(predictor_data,response_data(:,i)); 
end
% save('gprMdls_obstacle', 'gprMdls');
save('gprMdls_straight', 'gprMdls');

%% 
% Predict the response corresponding to the rows of |xi| (resubstitution
% predictions) using the trained model. 
test_data = [];
for i=1:2
    tmp = resubPredict(gprMdls{i,1});
    test_data = [test_data tmp];
end
%%
n = 100;
new_s = linspace(-pi, pi, n)';
new_x = ones(n,1)*700.*(1+sin(new_s));
new_y = linspace(-2100,2000,n)';
new_theta = ones(n,1)*pi/2;
new_pattern = ones(n,1)*1;
new_data = [new_x new_y new_theta zeros(n,3) new_pattern];

new_response = [];
for i=1:2
    ypred = predict(gprMdls{i,1}, new_data);
    new_response = [new_response ypred];
end


%%
if visualization
    figure(2)
    plot(predictor_data(:,1), predictor_data(:,2), 'k--')
    hold on
    plot(test_data(:,1), test_data(:,2), 'r')
    plot(new_response(:,1), new_response(:,2), 'b');
    plot(new_data(:,1), new_data(:,2), 'r');
    xlim([-2500 2500])
    num_points = size(new_data,1);
    for i=1:num_points
        xx=[new_data(i,1) new_response(i,1)];
        yy=[new_data(i,2) new_response(i,2)];
        plot(xx, yy)
    end
end
