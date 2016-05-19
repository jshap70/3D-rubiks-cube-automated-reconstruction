clc;
clear all;
close all;

addpath('images');
addpath(genpath('RANSAC-Toolbox'));

im1 = imread('13.jpg');
im2 = imread('14.jpg');

% select a single channel out of the images
im1 = im1(1:3:end,1:3:end,1);
im2 = im2(1:3:end,1:3:end,1);
% im1 = im1(:,:,1);
% im2 = im2(:,:,1);

%smooth = 2;
smooth = 2;
%thresh = 2000 ;  % Harris corner threshold
thresh = 1800;
%nonmaxrad = 10;  % Non-maximal suppression radius
nonmaxrad = 10;
%w = 91;         % Window size for correlation matching
w = 91;
%dmax = 50;     % Maximum search distance for matching
dmax = 80;


% Find Harris corners in image1 and image2
[cim1, r1, c1] = harris(im1, smooth, thresh, nonmaxrad);
show(im1,1), hold on, plot(c1,r1,'r+', 'LineWidth', 2);

[cim2, r2, c2] = harris(im2, smooth, thresh, nonmaxrad);
show(im2,2), hold on, plot(c2,r2,'r+', 'LineWidth', 2);

drawnow;
%pause;

correlation = 1;  % Change this between 1 or 0 to switch between the two
		  % matching functions below
    
if correlation    % Use normalised correlation matching
  [m1,m2] = matchbycorrelation(im1, [r1';c1'], im2, [r2';c2'], w, dmax);
else              % Use monogenic phase matching
  nscale = 2;
  minWaveLength = 10;
  mult = 4;
  sigmaOnf = .2;
  [m1,m2] = matchbymonogenicphase(im1, [r1';c1'], im2, [r2';c2'], w, dmax,...
				  nscale, minWaveLength, mult, sigmaOnf);
end    

% Display putative matches
show(double(im1)+double(im2),3), set(3,'name','Putative matches')
for n = 1:length(m1);
  line([m1(2,n) m2(2,n)], [m1(1,n) m2(1,n)], 'LineWidth', 2)
end

%pause;

% Assemble homogeneous feature coordinates for fitting of the
% fundamental matrix, note that [x,y] corresponds to [col, row]
x1 = [m1(2,:); m1(1,:); ones(1,length(m1))];
x2 = [m2(2,:); m2(1,:); ones(1,length(m1))];    
    
%t = .0001;  % Distance threshold for deciding outliers
t = .0008;

% Change the commenting on the lines below to switch between the use
% of 7 or 8 point fundamental matrix solutions, or affine
% fundamental matrix solution.
%[F, inliers] = ransacfitfundmatrix7(x1, x2, t, 1);    
[F, inliers] = ransacfitfundmatrix(x1, x2, t, 1);
%[F, inliers] = ransacfitaffinefund(x1, x2, t, 1);    

fprintf('Number of inliers was %d (%d%%) \n', ...
	length(inliers),round(100*length(inliers)/length(m1)))
fprintf('Number of putative matches was %d \n', length(m1))        

% Display both images overlayed with inlying matched feature points
show(double(im1)+double(im2),4), set(4,'name','Inlying matches'), hold on
plot(m1(2,inliers),m1(1,inliers),'r+', 'LineWidth', 2);
plot(m2(2,inliers),m2(1,inliers),'g+', 'LineWidth', 2);

for n = inliers
  line([m1(2,n) m2(2,n)], [m1(1,n) m2(1,n)],'color',[0 0 1], 'LineWidth', 2)
end

load('calib_final.mat', 'k');

k(1,1) = k(1,1)*1/3;
k(2,2) = k(2,2)*1/3;
k(1,3) = k(3,1)*1/3;
k(2,3) = k(3,1)*1/3;

[P1, P2, X] = get3dreconstruction(x1(1:2,inliers), x2(1:2,inliers), k);

figure(5)
plotPoints(X)

options.epsilon = 1e-6;
options.P_inlier = 0.95;
options.sigma = 0.005;
options.est_fun = @estimateplane;
options.man_fun = @estimateplane_error;
options.mode = 'MSAC';
options.Ps = [];
options.notify_iters = [];
options.min_iters = 1000;
options.fix_seed = false;
options.reestimate = true;
options.stabilize = false;

[results1, options] = RANSAC(X, options);
ind1 = results1.CS;
X1 = X(:, ind1);
% convert to 2d, get convex hull indeces, then add them back into X2 set

[~,n] = size(X1);
x1 = zeros(3, n);
for i=1:n
    temp = P1*X1(:,i);
    x1(:,i) = temp / temp(3);
end
c = convhull(x1(1,:), x1(2,:));


% figure(6)
% plotPoints(X1)

X2set = X(:, ~ind1);
[results2, options] = RANSAC(X2set, options);
ind2 = results2.CS;
X2 = X2set(:, ind2);
% figure(7)
% plotPoints(X2)

X3set = X(:, ~ind2);
[results3, options] = RANSAC(X3set, options);
ind3 = results3.CS;
X3 = X3set(:, ind3);
% figure(8)
% plotPoints(X3)

