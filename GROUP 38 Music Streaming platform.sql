/*

+-----------------------------------------------------------+
|                    GROUP 38 MUSIC STREAMING PLATFORM      |
+-----------------------------------------------------------+
|             												|
| 1.             Allan Kipyegon     Backend Developer		|
| 2.             KIlonzo Gloria     Backend Developer    	|
| 3.             Wambui Maina       Backend Developer 		|
| 4.			 Mahugu Gathu		Backend developer		|
| 5.			Otieno Calvin		Backend Developer		|
+-----------------------------------------------------------+
|     2024 . All rights Reserved							|
+-----------------------------------------------------------+

*/


/*
+-----------------------------------------------------------+
|                    Table Creation Scripts				    |
+-----------------------------------------------------------+

*/


DROP DATABASE IF EXISTS msc;
create database IF NOT EXISTS msc ;
use msc;

-- Users Table
CREATE TABLE IF NOT EXISTS Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    date_joined TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Artists Table
CREATE TABLE IF NOT EXISTS  Artists (
    artist_id INT PRIMARY KEY AUTO_INCREMENT,
    artist_name VARCHAR(100) NOT NULL,
    bio TEXT,
    monthly_listeners INT DEFAULT 0,
    country VARCHAR(50)
);

-- Albums Table
CREATE TABLE IF NOT EXISTS  Albums (
    album_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    artist_id INT,
    release_date DATE,
    total_tracks INT,
    genre VARCHAR(100),
    FOREIGN KEY (artist_id) REFERENCES Artists(artist_id)
);

-- Songs Table
CREATE TABLE IF NOT EXISTS  Songs (
    song_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    artist_id INT,
    album_id INT,
    genre VARCHAR(100),
    duration INT,   -- Duration in seconds
    release_date DATE,
    track_number INT,
    lyrics TEXT,
    play_count INT DEFAULT 0,
    FOREIGN KEY (artist_id) REFERENCES Artists(artist_id),
    FOREIGN KEY (album_id) REFERENCES Albums(album_id)
);

-- Playlists Table
CREATE TABLE IF NOT EXISTS  Playlists (
    playlist_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    user_id INT,
    description TEXT,
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

-- Playlist Songs Junction Table
CREATE TABLE IF NOT EXISTS  Playlist_Songs (
    playlist_id INT,
    song_id INT,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (playlist_id, song_id),
    FOREIGN KEY (playlist_id) REFERENCES Playlists(playlist_id),
    FOREIGN KEY (song_id) REFERENCES Songs(song_id)
);

-- Listening History Table
CREATE TABLE IF NOT EXISTS Listening_History (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    song_id INT,
    listen_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    listen_duration INT, 
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (song_id) REFERENCES Songs(song_id)
);

-- Likes Table
CREATE TABLE IF NOT EXISTS  Likes (
    user_id INT,
    song_id INT,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, song_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (song_id) REFERENCES Songs(song_id)
);

-- Premium Features Table
CREATE TABLE IF NOT EXISTS  premium_features (
    feature_id INT AUTO_INCREMENT PRIMARY KEY,
    feature_name VARCHAR(100) UNIQUE NOT NULL,
    feature_description TEXT,
    is_active BOOLEAN DEFAULT TRUE, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Subscription Plan Table
CREATE TABLE IF NOT EXISTS subscription_plan_features (
    Splan_id INT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    feature_id INT,
    price DECIMAL(10,2) NOT NULL,
    duration_months INT NOT NULL, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (feature_id) REFERENCES premium_features (feature_id)
);


-- Recommendation Table
CREATE TABLE IF NOT EXISTS  Recommendations (
    recommendation_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    song_id INT,
    recommendation_reason VARCHAR(255),
    recommendation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (song_id) REFERENCES Songs(song_id)
);

-- Payments Table
CREATE TABLE IF NOT EXISTS  Payments (
payments_ID INT AUTO_INCREMENT PRIMARY KEY,
user_id INT NOT NULL,
Splan_id INT NOT NULL,
amount DECIMAL (10,2) NOT NULL,
payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
payment_method VARCHAR (50), 
status ENUM('Pending', 'Completed', 'Failed') DEFAULT 'Pending',
FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
FOREIGN KEY (Splan_id) REFERENCES Subscription_plan_features(Splan_id) ON DELETE CASCADE
);


-- Subscription Plan Features Table
CREATE TABLE IF NOT EXISTS  user_subscriptions (
    subscription_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    Splan_id INT NOT NULL,
    subscription_status ENUM('active', 'cancelled', 'expired', 'inactive') DEFAULT 'inactive',
    start_date timestamp DEFAULT CURRENT_TIMESTAMP ,
    end_date DATE,
    payment_status ENUM('paid', 'unpaid') DEFAULT 'unpaid',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (Splan_id) REFERENCES subscription_plan_features(Splan_id) ON DELETE CASCADE
);

/*
+-----------------------------------------------------------+
|                    Triggers               			    |
+-----------------------------------------------------------+

*/

DELIMITER $$

CREATE TRIGGER hash_password_before_insert
BEFORE INSERT ON Users
FOR EACH ROW
BEGIN
    SET NEW.password = SHA2(NEW.password, 256);
END$$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER update_subscription_on_payment
AFTER UPDATE ON Payments
FOR EACH ROW
BEGIN
    -- Check if the payment status has been updated to 'Completed'
    IF NEW.status = 'Completed' THEN
        -- Update the subscription status to active and payment status to paid
        UPDATE user_subscriptions
        SET subscription_status = 'active',
            payment_status = 'paid',
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = NEW.user_id
        AND Splan_id = NEW.Splan_id;
    END IF;
END $$

DELIMITER ;


DROP TRIGGER IF EXISTS update_monthly_listeners;
delimiter $$

CREATE TRIGGER update_monthly_listeners -- importance - Keep track of number of montly listeners
AFTER INSERT ON Listening_History
FOR EACH ROW
BEGIN
    DECLARE current_listeners INT;
    SELECT monthly_listeners INTO current_listeners FROM Artists 
    WHERE artist_id = (
										SELECT artist_id FROM Songs 
                                        WHERE
                                        song_id = NEW.song_id 
                                        );
    UPDATE Artists 
    SET monthly_listeners = current_listeners + 1 
    WHERE artist_id = (SELECT artist_id FROM Songs WHERE song_id = NEW.song_id);
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS prevent_multiple_active_subscriptions;
DELIMITER $$ -- importance prevent multiple subscriptions
CREATE TRIGGER prevent_multiple_active_subscriptions  
BEFORE INSERT ON user_subscriptions
FOR EACH ROW
BEGIN
    DECLARE active_subscriptions INT;

    -- Check for active subscriptions
    SELECT COUNT(*) INTO active_subscriptions 
    FROM user_subscriptions 
    WHERE user_id = NEW.user_id 
      AND subscription_status = 'active'
      AND CURRENT_DATE BETWEEN start_date AND DATE_ADD(start_date, INTERVAL (SELECT duration_months FROM subscription_plan_features WHERE Splan_id = NEW.Splan_id) MONTH);

    IF active_subscriptions > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User already has an active subscription.';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS `Show All User Subscriptions`;
DELIMITER $$
CREATE PROCEDURE `Show All User Subscriptions`()
BEGIN 
SELECT * FROM User_subscriptions;
END $$
DElIMITER ;

DROP TRIGGER IF EXISTS increment_play_count;
DELIMITER $$

CREATE TRIGGER increment_play_count  -- tracks number of times a song has been played 
AFTER INSERT ON Listening_History
FOR EACH ROW
BEGIN
    UPDATE Songs 
    SET play_count = play_count + 1  
    WHERE song_id = NEW.song_id;     
END $$
DELIMITER;

DROP TRIGGER IF EXISTS delete_playlist_songs_on_song_delete;
delimiter $$
CREATE TRIGGER delete_playlist_songs_on_song_delete -- Importance - It maintains referencial Integrity.ie kill orphan if parent is killed!
BEFORE DELETE ON Songs
FOR EACH ROW
BEGIN
    DELETE FROM Playlist_Songs 
    WHERE song_id = OLD.song_id;
END $$


DROP TRIGGER IF EXISTS set_end_date_before_insert;
DELIMITER $$
CREATE TRIGGER set_end_date_before_insert
BEFORE INSERT ON user_subscriptions
FOR EACH ROW
BEGIN
    DECLARE duration_months INT;

    SELECT duration_months
    INTO duration_months
    FROM subscription_plan_features
    WHERE Splan_id = NEW.Splan_id;

    IF duration_months IS NULL THEN
        SET duration_months = 3;
    END IF;

    SET NEW.end_date = DATE_ADD(NEW.start_date, INTERVAL duration_months MONTH);
END$$
DELIMITER ;


/*
+-----------------------------------------------------------+
|                    Events  	              			    |
+-----------------------------------------------------------+

*/



SET GLOBAL event_scheduler = ON;


-- update expired subscription
DELIMITER $$
CREATE EVENT IF NOT EXISTS update_expired_subscriptions -- automaticallly update user subscription status
ON SCHEDULE EVERY 1 DAY 
DO
BEGIN
    UPDATE user_subscriptions
    SET subscription_status = 'expired'
    WHERE end_date < CURDATE() AND subscription_status != 'expired';
END $$

DELIMITER ;



/*
+-----------------------------------------------------------+
|                   CRUD OPERATIONS            			    |
+-----------------------------------------------------------+

*/

INSERT INTO Users (username, email, password)
VALUES
    ('john', 'john@mail.com', 'password_1234'),
    ('jane', 'jane@domain.com', 'password_5678'),
    ('mike', 'mike123@gmail.com', 'securePassword1'),
    ('sarah', 'sarah@hotmail.com', 'mySuperSecret2'),
    ('alex', 'alex@outlook.com', 'turnerPass3'),
    ('emma', 'emma@ymail.com', 'passwordEmma4'),
    ('lucas', 'lucas@icloud.com', 'blackSecure5'),
    ('olivia', 'olivia@aol.com', 'brownPass6'),
    ('daniel', 'daniel@mail.com', 'Miller1234'),
    ('sophie', 'sophie@yahoo.com', 'DavisPass7');
    
INSERT INTO Artists (artist_name, bio, monthly_listeners, country)
VALUES
    ('Adele', 'Adele Laurie Blue Adkins, an English singer-songwriter, is known for her powerful vocals and emotional ballads.', 35000000, 'United Kingdom'),
    ('Drake', 'A Canadian rapper, singer, and songwriter who blends hip-hop, pop, and R&B.', 45000000, 'Canada'),
    ('BTS', 'A South Korean boy band known for their fusion of K-pop, hip-hop, and electronic music.', 60000000, 'South Korea'),
    ('Ed Sheeran', 'An English singer-songwriter, famous for his heartfelt lyrics and hit singles like "Shape of You".', 40000000, 'United Kingdom'),
    ('Taylor Swift', 'An American singer-songwriter who has evolved from country to pop, with numerous chart-topping hits.', 50000000, 'United States'),
    ('Billie Eilish', 'An American singer known for her introspective lyrics and genre-blending sound.', 30000000, 'United States'),
    ('The Weeknd', 'A Canadian artist known for his falsetto voice and a blend of R&B and pop.', 50000000, 'Canada'),
    ('Shakira', 'A Colombian singer-songwriter who merges Latin, pop, and rock, famous for songs like "Hips Don\'t Lie".', 25000000, 'Colombia'),
    ('Kendrick Lamar', 'An American rapper known for his socially conscious lyrics and dynamic sound in hip-hop.', 35000000, 'United States'),
    ('Bruno Mars', 'An American singer, songwriter, and producer known for his retro style and energetic performances.', 45000000, 'United States');
    
    
INSERT INTO Albums (title, artist_id, release_date, total_tracks, genre)
VALUES
    ('25', 1, '2015-11-20', 11, 'Pop'),
    ('Scorpion', 2, '2018-06-29', 25, 'Hip-Hop/Rap'),
    ('Map of the Soul: 7', 3, '2020-02-21', 20, 'K-pop'),
    ('Divide', 4, '2017-03-03', 12, 'Pop'),
    ('Fearless', 5, '2008-11-11', 13, 'Country/Pop'),
    ('When We All Fall Asleep, Where Do We Go?', 6, '2019-03-29', 14, 'Pop'),
    ('After Hours', 7, '2020-03-20', 14, 'R&B/Pop'),
    ('Shakira: Oral Fixation Vol. 2', 8, '2005-11-29', 12, 'Latin Pop'),
    ('DAMN.', 9, '2017-04-14', 14, 'Hip-Hop/Rap'),
    ('24K Magic', 10, '2016-11-18', 9, 'Pop/Funk');
    
INSERT INTO Songs (title, artist_id, album_id, genre, duration, release_date, track_number, lyrics, play_count)
VALUES
    ('Hello', 1, 1, 'Pop', 295, '2015-10-23', 1, 'Hello, it\'s me, I was wondering if after all these years you\'d like to meet...', 1500),
    ('God\'s Plan', 2, 2, 'Hip-Hop/Rap', 198, '2018-02-16', 4, 'I been down so long, they look like up to me...', 120),
    ('Dynamite', 3, 3, 'K-pop', 195, '2020-08-21', 1, 'Cause I, I, I, I’m in the stars tonight...', 500),
    ('Shape of You', 4, 4, 'Pop', 233, '2017-01-06', 1, 'The club isn\'t the best place to find a lover...',90),
    ('Love Story', 5, 5, 'Country/Pop', 240, '2008-09-15', 1, 'We were both young when I first saw you...', 80),
    ('Bad Guy', 6, 6, 'Pop', 194, '2019-03-29', 1, 'White shirt now red, my bloody nose...', 30),
    ('Blinding Lights', 7, 7, 'R&B/Pop', 200, '2020-03-20', 1, 'I said, ooh, I\'m blinded by the lights...', 50),
    ('Hips Don\'t Lie', 8, 8, 'Latin Pop', 238, '2006-02-23', 1, 'I never really knew that she could dance like this...', 15),
    ('HUMBLE.', 9, 9, 'Hip-Hop/Rap', 177, '2017-03-30', 1, 'Nobody pray for me, it\'s been that day for me...', 25),
    ('Uptown Funk', 10, 10, 'Pop/Funk', 270, '2014-11-10', 1, 'This hit, that ice cold, Michelle Pfeiffer, that white gold...', 4);
    
INSERT INTO Playlists (name, user_id, description)
VALUES
    ('Morning Vibes', 1, 'A playlist to get your morning started with energy and calm melodies.'),
    ('Workout Motivation', 2, 'A playlist of high-energy songs to power you through a tough workout.'),
    ('Chill Beats', 3, 'Perfect for relaxing, studying, or winding down after a busy day.'),
    ('Top Hits', 4, 'A collection of the latest trending songs and top charts hits.'),
    ('Throwback Jams', 5, 'A nostalgic playlist featuring classic tracks from the 90s and 2000s.'),
    ('Summer Essentials', 6, 'A playlist full of upbeat songs to celebrate the summer season.'),
    ('Rap Essentials', 7, 'The best rap songs to keep your head nodding.'),
    ('Romantic Playlist', 8, 'A mix of soft and loving songs for date night.'),
    ('Party Playlist', 9, 'Get the party started with these dance-worthy tunes.'),
    ('Indie Discoveries', 10, 'For the indie music lover, a curated list of up-and-coming artists');
    
INSERT INTO Playlist_Songs (playlist_id, song_id)
VALUES
    (1, 1 ),
    (1, 2),
    (2, 3),
    (2, 4),
    (3, 5),
    (3, 6),
    (4, 7),
    (4, 8),
    (5, 9),
    (5, 10);
    

INSERT INTO Listening_History (user_id, song_id, listen_time, listen_duration)
VALUES 
(1, 1, '2024-11-19 10:00:00', 180),
(2, 3, '2024-11-19 10:15:00', 220),
(3, 2, '2024-11-19 10:30:00', 150),
(4, 4, '2024-11-19 10:45:00', 210),
(5, 5, '2024-11-19 11:00:00', 200),
(6, 6, '2024-11-19 11:15:00', 250),
(7, 1, '2024-11-19 11:30:00', 180),
(8, 2, '2024-11-19 11:45:00', 190),
(9, 3, '2024-11-19 12:00:00', 170),
(10, 4, '2024-11-19 12:15:00', 240);
 
    
INSERT INTO Likes (user_id, song_id)
VALUES
    (1, 1 ),
    (2, 2 ),
    (3, 3),
    (4, 4),
    (5, 5),
    (6, 6),
    (7, 7),
    (8, 8),
    (9, 9),
    (10, 10);
    
INSERT INTO premium_features (feature_name, feature_description, is_active)
VALUES 
('Advanced Analytics', 'Provides detailed data analysis and reporting tools.', TRUE),
('Ad-Free Experience', 'Removes all advertisements from the platform.', TRUE),
('Priority Support', 'Offers priority access to customer support for quick resolutions.', TRUE),
('Exclusive Content', 'Unlocks exclusive content that is only available to premium users.', TRUE),
('Offline Access', 'Allows users to access content offline without an internet connection.', TRUE),
('Early Access', 'Grants early access to new features and updates before general release.', TRUE),
('Customizable Themes', 'Allows users to customize the visual theme of the platform.', TRUE),
('Increased Storage', 'Provides additional storage space for files and data.', TRUE),
('Enhanced Security', 'Adds extra layers of security to user accounts and data.', TRUE),
('Premium API Access', 'Gives users access to premium APIs for advanced integrations.', TRUE);


INSERT INTO subscription_plan_features (plan_name, feature_id, price, duration_months)
VALUES
('Basic Plan', 1,9.99, 1),
('Standard Plan',2, 19.99, 3),
('Premium Plan',3, 29.99, 6),
('Gold Plan',4, 49.99, 12),
('Silver Plan',5, 15.99, 3),
('Platinum Plan',6, 79.99, 12),
('Family Plan',7, 39.99, 6),
('Student Plan',8, 5.99, 1),
('Business Plan',9, 99.99, 24),
('VIP Plan', 10,149.99, 12);


INSERT INTO Recommendations (user_id, song_id, recommendation_reason)
VALUES
    (1, 1, 'This song is perfect for a morning playlist to start your day off with energy!'),
    (2, 3, 'Great for relaxing or studying, perfect chill vibe for a productive day.'),
    (3, 5, 'The catchy beat and lyrics make it a great workout anthem!'),
    (4, 7, 'A perfect song for a summer road trip, full of fun energy and nostalgia.'),
    (5, 10, 'An upbeat song that brings back great memories from the 90s, a true throwback hit!'),
    (6, 4, 'Ed Sheeran voice is perfect for a romantic evening playlist, timeless track!'),
    (7, 6, 'Billie Eilish brings a unique sound that fits the perfect late-night listening vibe.'),
    (8, 8, 'Shakira rhythm is irresistible, perfect for dancing or a high-energy workout session.'),
    (9, 9, 'Kendrick Lamar’s lyrics are deep and impactful, a great choice for introspective moments.'),
    (10, 2, 'A dance worthy anthem that will get everyone moving and energized');


INSERT INTO Payments (user_id, Splan_id, amount, payment_method, status)
VALUES 
(1, 2, 29.99, 'Credit Card', 'Completed'),
(2, 1, 19.99, 'PayPal', 'Completed'),
(3, 3, 49.99, 'Debit Card', 'Pending'),
(4, 2, 29.99, 'Credit Card', 'Completed'),
(5, 1, 19.99, 'Bank Transfer', 'Failed'),
(6, 3, 49.99, 'Credit Card', 'Completed'),
(7, 2, 29.99, 'PayPal', 'Completed'),
(8, 1, 19.99, 'Credit Card', 'Pending'),
(9, 2, 29.99, 'Debit Card', 'Completed'),
(10, 3, 49.99, 'PayPal', 'completed');


-- Insert 10 sample rows into user_subscriptions table
INSERT INTO user_subscriptions (user_id, Splan_id, subscription_status, start_date, end_date, payment_status)
VALUES 
(1, 1, 'active', '2024-01-01', '2024-12-31', 'paid'),
(2, 2, 'active', '2024-02-01', '2025-01-31', 'paid'),
(3, 3, 'cancelled', '2024-03-01', '2024-08-31', 'unpaid'),
(4, 1, 'expired', '2023-01-01', '2023-12-31', 'paid'),
(5, 2, 'active', '2024-04-01', '2025-03-31', 'unpaid'),
(6, 3, 'active', '2024-05-01', '2025-04-30', 'paid'),
(7, 1, 'cancelled', '2024-06-01', '2024-11-30', 'paid'),
(8, 2, 'active', '2024-07-01', '2025-06-30', 'paid'),
(9, 3, 'expired', '2023-05-01', '2023-10-31', 'unpaid'),
(10, 1, 'active', '2024-08-01', '2025-07-31', 'paid');


/*
+-----------------------------------------------------------+
|                    Views		            			    |
+-----------------------------------------------------------+

*/


-- User Profile
CREATE OR REPLACE VIEW user_profile AS 
SELECT
 u.user_id,
 u.username,
 u.email,
 COUNT(DISTINCT lh.song_id) AS total_songs_listened,
 COUNT(DISTINCT p.playlist_id) AS total_playlists
 FROM
  users u
  LEFT JOIN 
  listening_history lh ON u.user_id = lh.user_id
  LEFT JOIN
  playlists p ON u.user_id = p.user_id
  GROUP BY
  u.user_id;
  
-- Song Details View
  CREATE OR REPLACE VIEW song_details AS
SELECT
   s.song_id,
   s.title AS song_title,
   a.title AS album_title,
   ar.artist_name AS artist_name,
   s.duration
FROM
   songs s
JOIN
   albums a ON s.album_id = a.album_id
JOIN
   artists ar ON s.artist_id = ar.artist_id;
   
-- Listening History View
CREATE OR REPLACE VIEW user_listening_history AS
SELECT
   lh.history_id,
   u.username,
   s.title AS song_title,
   ar.artist_name AS artist_name,
   lh.listen_time
FROM
   listening_history lh
JOIN
   users u ON lh.user_id = u.user_id
JOIN
   songs s ON lh.song_id = s.song_id
JOIN
   artists ar ON s.artist_id = ar.artist_id
ORDER BY
   lh.listen_time DESC;



CREATE OR REPLACE VIEW liked_songs AS
SELECT
   s.song_id,
   s.title,
   ar.artist_name AS artist_name, 
   COUNT(l.user_id) AS like_count  
FROM
   songs s
JOIN
   artists ar ON s.artist_id = ar.artist_id
LEFT JOIN
   likes l ON s.song_id = l.song_id
GROUP BY
   s.song_id, ar.artist_name  
ORDER BY
   like_count DESC;

   
-- User Payment History View
CREATE OR REPLACE VIEW user_payment_history AS
SELECT
   p.payments_id,
   u.username,
   p.amount,
   p.payment_date,
   p.payment_method
FROM
   payments p
JOIN
   users u ON p.user_id = u.user_id
ORDER BY
   p.payment_date DESC;
   
-- Playlist Songs View
CREATE OR REPLACE VIEW playlist_songs_view AS
SELECT
   pl.playlist_id,
   ar.artist_name AS playlist_name,
   s.title AS song_title,
   ar.artist_name AS artist_name
FROM
   playlist_songs ps
JOIN
   playlists pl ON ps.playlist_id = pl.playlist_id
JOIN
   songs s ON ps.song_id = s.song_id
JOIN
   artists ar ON s.artist_id = ar.artist_id;
   
-- Recommendations View
CREATE OR REPLACE VIEW user_recommendations AS 
SELECT
   r.recommendation_id,
   u.username,
   s.title AS song_title,
   ar.artist_name AS artist_name,
   r.recommendation_date
FROM
   recommendations r
JOIN
   users u ON r.user_id = u.user_id
JOIN
   songs s ON r.song_id = s.song_id
JOIN
   artists ar ON s.artist_id = ar.artist_id
ORDER BY
   r.recommendation_date DESC;
   

-- View to display Subscription Plans with Features
CREATE OR REPLACE VIEW subscription_plans_with_features AS
SELECT
   sp.Splan_id,
   sp.plan_name,
   sp.price,
   sp.duration_months,
   pf.feature_name
FROM
   subscription_plan_features sp
JOIN
   subscription_plan_features spf ON sp.Splan_id = spf.Splan_id
JOIN
   premium_features pf ON spf.feature_id = pf.feature_id;


/*
+-----------------------------------------------------------+
|                    Procedures								|
+-----------------------------------------------------------+

*/


DROP PROCEDURE IF EXISTS `PayForSubscription`;
DELIMITER $$

DROP PROCEDURE IF EXISTS `PayForSubscription`;
DELIMITER $$

CREATE PROCEDURE `PayForSubscription` (
    IN p_user_id INT,
    IN p_Splan_id INT,
    IN p_payment_method VARCHAR(50)
)
BEGIN
    -- Declare variables at the top of the procedure
    DECLARE v_price DECIMAL(10, 2);
    DECLARE v_payment_id INT;
    DECLARE v_payment_status ENUM('Pending', 'Completed', 'Failed') DEFAULT 'Pending';

    -- Fetch the price for the subscription plan
    SELECT price INTO v_price
    FROM subscription_plan_features
    WHERE Splan_id = p_Splan_id;

    -- If the plan is not found, raise an error
    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subscription plan not found';
    END IF;

    -- Insert the payment record with the initial 'Pending' status
    INSERT INTO Payments (user_id, Splan_id, amount, payment_method, status)
    VALUES (p_user_id, p_Splan_id, v_price, p_payment_method, v_payment_status);

    -- Fetch the last inserted payment ID
    SET v_payment_id = LAST_INSERT_ID();

    -- Update the payment record to 'Completed' and set the payment_date
    UPDATE Payments
    SET status = 'Completed',
        payment_date = CURRENT_TIMESTAMP
    WHERE payments_ID = v_payment_id;

    -- Update the user subscription to reflect the payment completion
    UPDATE user_subscriptions
    SET payment_status = 'paid',
        subscription_status = 'active',
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
      AND Splan_id = p_Splan_id
      AND subscription_status = 'inactive';
END$$

DELIMITER ;






DROP PROCEDURE IF EXISTS `Add New User`;
DELIMITER //
CREATE PROCEDURE `Add New User` (
    IN p_username VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_password VARCHAR(255)
)
BEGIN
    INSERT INTO Users (username, email, password)
    VALUES (p_username, p_email, p_password);
END //
DELIMITER ;

-- Add song to Playlist
DROP  PROCEDURE IF EXISTS AddSongToPlaylist;
DELIMITER //
CREATE PROCEDURE AddSongToPlaylist(
    IN p_playlist_id INT,
    IN p_song_id INT
)
BEGIN
    INSERT INTO playlist_songs (playlist_id, song_id)
    VALUES (p_playlist_id, p_song_id);
END //
DELIMITER ;


-- Update User Information
DROP PROCEDURE IF EXISTS `Update User Subscription`;
DELIMITER //
CREATE PROCEDURE `Add User Subscription` (
    IN p_user_id INT,
    IN P_splan_id INT   
)
BEGIN
    UPDATE User_subscriptions
    SET Splan_id = P_splan_id
    WHERE user_id = p_user_id;
    
    UPDATE user_subscriptions
    SET payment_status = 'unpaid',
		subscription_status = 'expired'
    WHERE Splan_id = p_splan_id;
END //
DELIMITER ;

-- Get all songs by Artist
DROP PROCEDURE IF EXISTS GetSongsByArtist;
DELIMITER //
CREATE PROCEDURE GetSongsByArtist (
    IN p_artist_id INT
)
BEGIN
    SELECT * FROM Songs WHERE artist_id = p_artist_id;
END //
DELIMITER ;

-- Get all albums by artist
DROP  PROCEDURE IF EXISTS GetAlbumsByArtist;
DELIMITER //
CREATE PROCEDURE GetAlbumsByArtist (
    IN p_artist_id INT
)
BEGIN
    SELECT * FROM Albums WHERE artist_id = p_artist_id;
END //
DELIMITER ;

-- Get user playlists
DROP PROCEDURE IF EXISTS GetPlaylistsByUser;
DELIMITER //
CREATE PROCEDURE GetPlaylistsByUser (
    IN p_user_id INT
)
BEGIN
    SELECT * FROM Playlists WHERE user_id = p_user_id;
END //
DELIMITER ;

--  Remove song from playlist
DROP PROCEDURE IF EXISTS RemoveSongFromPlaylist;
DELIMITER //
CREATE PROCEDURE RemoveSongFromPlaylist (
    IN p_playlist_id INT,
    IN p_song_id INT
)
BEGIN
    DELETE FROM Playlist_Songs
    WHERE playlist_id = p_playlist_id AND song_id = p_song_id;
END //
DELIMITER ;

-- Get listening history for a user
DROP PROCEDURE IF EXISTS GetListeningHistory;
DELIMITER //
CREATE PROCEDURE GetListeningHistory (
    IN p_user_id INT
)
BEGIN
    SELECT Songs.title, Listening_History.listen_time
    FROM Listening_History
    JOIN Songs ON Listening_History.song_id = Songs.song_id
    WHERE Listening_History.user_id = p_user_id
    ORDER BY Listening_History.listen_time DESC;
END //
DELIMITER ;

-- Like song
DROP PROCEDURE IF EXISTS `Like Songs`;
DELIMITER //
CREATE PROCEDURE `Like Songs` (
    IN p_user_id INT,
    IN p_song_id INT
)
BEGIN
    INSERT INTO Likes (user_id, song_id, date_added)
    VALUES (p_user_id, p_song_id, NOW());
END //
DELIMITER ;

-- Unlike a song
DROP PROCEDURE IF EXISTS `Unlike song`;
DELIMITER //
CREATE PROCEDURE `Unlike Song` (
    IN p_user_id INT,
    IN p_song_id INT
)
BEGIN
    DELETE FROM Likes
    WHERE user_id = p_user_id AND song_id = p_song_id;
END //
DELIMITER ;

-- Get liked songs for a user
DROP PROCEDURE IF EXISTS GetLikedSongs;
DELIMITER //
CREATE PROCEDURE GetLikedSongs (
    IN p_user_id INT
)
BEGIN
    SELECT Songs.*
    FROM likes
    JOIN Songs ON Likes.song_id = Songs.song_id
    WHERE Likes.user_id = p_user_id;
END //
DELIMITER ;

-- Create Subscription plan
DROP PROCEDURE IF EXISTS `Create Subscription Plan`; 
DELIMITER //
CREATE PROCEDURE `Create Subscription Plan` (
    IN p_Splan_name VARCHAR(50),
    IN p_feature_id INT,
    IN p_price DECIMAL(10, 2),
    IN p_duration_months INT
 )
BEGIN
    INSERT INTO Subscription_Plan_features (plan_name,feature_id, price, duration_months)
    VALUES (p_Splan_name,p_feature_id, p_price, p_duration_months);
END //
DELIMITER ;

-- Update Subscription plan 
DROP PROCEDURE IF EXISTS `Update Existing Subscription Plan`;
DELIMITER //
CREATE PROCEDURE `Update Existing Subscription Plan` (
    IN p_Splan_id INT,
    IN p_plan_name VARCHAR(50),
    IN p_price DECIMAL(10, 2),
    IN p_duration_months INT
)
BEGIN
    UPDATE Subscription_Plan_features
    SET plan_name = p_plan_name,
        price = p_price,
        duration_months = p_duration_months
    WHERE Splan_id = p_Splan_id;
END //
DELIMITER ;



/*
+-----------------------------------------------------------+
|                    Advanced Queries          			    |
+-----------------------------------------------------------+

*/


SELECT 
    s.title AS `Song Title`, 
    a.artist_name AS `Artist Name`,
    COUNT(lh.song_id) AS `Listen Count`, 
    IFNULL(COUNT(ps.song_id), 0) AS `Playlist Count`,  
    (COUNT(lh.song_id) * 0.7 + IFNULL(COUNT(ps.song_id), 0) * 0.3)*100 AS RecommendationScore 
FROM 
    Users u
JOIN 
    Listening_History lh ON u.user_id = lh.user_id
JOIN 
    Songs s ON lh.song_id = s.song_id
JOIN 
    Artists a ON s.artist_id = a.artist_id
LEFT JOIN 
    Playlist_Songs ps ON s.song_id = ps.song_id
WHERE 
    u.user_id = 5
GROUP BY 
    s.song_id, a.artist_name
HAVING
    RecommendationScore > 50  -- filtering by the calculated recommendation score
ORDER BY 
    RecommendationScore DESC
LIMIT 10;




-- Printing each song play count.
SELECT 
    a.artist_name AS `Artist Name`,
    SUM(s.play_count) AS `Total no of Plays`
FROM 
    Artists a
INNER JOIN 
    Songs s ON a.artist_id = s.artist_id
GROUP BY 
    a.artist_id
ORDER BY 
    `Total no of Plays` DESC;


-- Selecting the top 10 recommended songs for the user.
SELECT 
    r.recommendation_reason AS `Recommendation Reason`,
    s.title AS `Song Title`,
    a.artist_name AS `Artist Name`,
    r.recommendation_date AS `Recommendation Date`
FROM 
    Recommendations r
JOIN 
    Songs s ON r.song_id = s.song_id
JOIN 
    Artists a ON s.artist_id = a.artist_id
WHERE 
    r.user_id = 1
ORDER BY 
    r.recommendation_date DESC
LIMIT 10;



-- Print recently played songs by the user.
SELECT 
    s.title AS `Song Title`, 
    a.artist_name AS `Artist Name`, 
    lh.listen_time AS `Listen Time`
FROM 
    Listening_History lh
JOIN 
    Songs s ON lh.song_id = s.song_id
JOIN 
    Artists a ON s.artist_id = a.artist_id
WHERE 
    lh.user_id = 2 
ORDER BY 
    lh.listen_time DESC
LIMIT 10;



-- Select all songs liked by a user.
SELECT 
    s.title AS `Song Title`,
    s.genre AS `Genre`,
    a.artist_name AS `Artist Name`
FROM 
    Likes l
INNER JOIN 
    Songs s ON l.song_id = s.song_id
INNER JOIN 
    Artists a ON s.artist_id = a.artist_id
WHERE 
    l.user_id = 2;



-- Users without playlists.
SELECT 
    u.username, 
    u.email AS `User Email`
FROM 
    Users u
LEFT JOIN 
    Playlists p ON u.user_id = p.user_id
WHERE 
    p.user_id IS NULL;


-- All users and their subscription plans.
SELECT 
	u.user_id,
    u.username AS `User Name`, 
    spf.plan_name AS `Plan Name`, 
    spf.price AS `Price`,
    us.subscription_status
    
FROM 
    Users u
RIGHT JOIN 
    user_subscriptions us ON u.user_id = us.user_id
INNER JOIN 
	subscription_plan_features spf ON us.Splan_id = spf.Splan_id;


-- Fetch recommendations using song and user info.
SELECT 
    u.username AS `Username`,
    s.title AS `Song Title`,
    r.recommendation_reason AS `Reason`,
    r.recommendation_date AS `Recommendation Date`
FROM 
    Recommendations r
INNER JOIN 
    Users u ON r.user_id = u.user_id
INNER JOIN 
    Songs s ON r.song_id = s.song_id
WHERE 
    r.user_id = 1;
    
/*
+-----------------------------------------------------------+
|                   Reports			          			    |
+-----------------------------------------------------------+

*/

DROP  PROCEDURE IF EXISTS sp_monthly_user_growth_report;
DELIMITER //
CREATE PROCEDURE sp_monthly_user_growth_report(IN p_year INT, IN p_month INT)
BEGIN
    SELECT 
        YEAR(date_joined) AS report_year,
        MONTH(date_joined) AS report_month,
        COUNT(*) AS new_users
    FROM 
        users
    WHERE 
        YEAR(date_joined) = p_year 
        AND MONTH(date_joined) = p_month
    GROUP BY 
        YEAR(date_joined), 
        MONTH(date_joined);
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_artist_performance_report;
DELIMITER //
CREATE PROCEDURE sp_artist_performance_report(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    SELECT 
        a.artist_id,
        a.artist_name,
        COUNT(DISTINCT s.song_id) AS total_songs,
        COUNT(DISTINCT al.album_id) AS total_albums,
        SUM(s.play_count) AS total_streams,
        AVG(s.play_count) AS avg_streams_per_song,
        COUNT(DISTINCT lh.user_id) AS unique_listeners
    FROM 
        artists a
    LEFT JOIN 
        songs s ON a.artist_id = s.artist_id
    LEFT JOIN 
        albums al ON a.artist_id = al.artist_id
    LEFT JOIN 
        listening_history lh ON s.song_id = lh.song_id
    WHERE 
        s.release_date BETWEEN p_start_date AND p_end_date
    GROUP BY 
        a.artist_id, 
        a.artist_name
    ORDER BY 
        total_streams DESC;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_subscription_revenue_report;
DELIMITER //
CREATE PROCEDURE sp_subscription_revenue_report(IN p_year INT)
BEGIN
    SELECT 
        YEAR(payment_date) AS report_year,
        MONTH(payment_date) AS report_month,
        sp.Splan_id,
        COUNT(*) AS total_subscriptions,
        SUM(p.amount) AS total_revenue,
        AVG(p.amount) AS avg_subscription_price
    FROM 
        payments p
    JOIN 
        user_subscriptions sp ON p.Splan_id = sp.Splan_id
    WHERE 
        YEAR(payment_date) = p_year
    GROUP BY 
        YEAR(payment_date),
        MONTH(payment_date),
        sp.Splan_id
    ORDER BY 
        report_year, 
        report_month;
END//
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_genre_popularity_report;
DELIMITER //
CREATE PROCEDURE sp_genre_popularity_report(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    SELECT 
        s.genre,
        COUNT(DISTINCT s.song_id) AS total_songs,
        SUM(s.play_count) AS total_plays,
        COUNT(DISTINCT lh.user_id) AS unique_listeners,
        (SUM(s.play_count) / COUNT(DISTINCT s.song_id)) AS avg_plays_per_song
    FROM 
        songs s
    LEFT JOIN 
        listening_history lh ON s.song_id = lh.song_id
    WHERE 
        s.release_date BETWEEN p_start_date AND p_end_date
    GROUP BY 
        s.genre
    ORDER BY 
        total_plays DESC;
END//
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_user_engagement_report;
DELIMITER //
CREATE PROCEDURE sp_user_engagement_report(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    SELECT 
        u.user_id,
        u.username,
        COUNT(DISTINCT lh.song_id) AS unique_songs_played,
        COUNT(DISTINCT p.playlist_id) AS total_playlists,
        COUNT(DISTINCT l.song_id) AS liked_songs,
        AVG(DATEDIFF(CURRENT_DATE, lh.listen_time)) AS avg_days_since_last_play
    FROM 
        users u
    LEFT JOIN 
        listening_history lh ON u.user_id = lh.user_id
    LEFT JOIN 
        playlists p ON u.user_id = p.user_id
    LEFT JOIN 
        likes l ON u.user_id = l.user_id
    WHERE 
        lh.listen_time BETWEEN p_start_date AND p_end_date
    GROUP BY 
        u.user_id, 
        u.username
    ORDER BY 
        unique_songs_played DESC
    LIMIT 100;
END//
DELIMITER;

DROP PROCEDURE IF EXISTS sp_playlist_analysis_report;
DELIMITER //
CREATE PROCEDURE sp_playlist_analysis_report(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    SELECT 
        p.playlist_id,
        p.name,
        u.username AS created_by,
        COUNT(DISTINCT ps.song_id) AS total_songs,
        COUNT(DISTINCT lh.user_id) AS times_played,
        AVG(s.play_count) AS avg_song_plays
    FROM 
        playlists p
    JOIN 
        users u ON p.user_id = u.user_id
    LEFT JOIN 
        playlist_songs ps ON p.playlist_id = ps.playlist_id
    LEFT JOIN 
        songs s ON ps.song_id = s.song_id
    LEFT JOIN 
        listening_history lh ON lh.song_id = ps.song_id
    WHERE 
        p.date_created BETWEEN p_start_date AND p_end_date
    GROUP BY 
        p.playlist_id, 
        p.name, 
        u.username
    ORDER BY 
        times_played DESC;
END//
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_platform_analytics_report;
DELIMITER // 
CREATE PROCEDURE sp_platform_analytics_report(IN p_start_date DATE, IN p_end_date DATE)
BEGIN
    -- Overall Platform Metricsliked_songs
    SELECT 
	
        (SELECT COUNT(*) FROM users WHERE date_joined BETWEEN p_start_date AND p_end_date) AS new_users,
        
		
        (SELECT COUNT(*) FROM songs WHERE release_date BETWEEN p_start_date AND p_end_date) AS new_songs,
        (SELECT COUNT(*) FROM albums WHERE release_date BETWEEN p_start_date AND p_end_date) AS new_albums,
        
		
        (SELECT SUM(play_count) FROM songs WHERE release_date BETWEEN p_start_date AND p_end_date) AS total_streams,
        
			
        (SELECT SUM(amount) FROM payments WHERE payment_date BETWEEN p_start_date AND p_end_date) AS total_revenue,
        
		
        (SELECT COUNT(*) FROM listening_history WHERE listen_time BETWEEN p_start_date AND p_end_date) AS total_plays,
        (SELECT COUNT(DISTINCT user_id) FROM listening_history WHERE listen_time BETWEEN p_start_date AND p_end_date) AS active_users;
END//
DELIMITER ;


/*
+-----------------------------------------------------------+
|                   SECURITY	AND PRIVILEDGES			    |
+-----------------------------------------------------------+

*/

-- view user accounts and priveledges

SELECT * FROM mysql.user;


-- view all user priveledges
SHOW GRANTS FOR 'root'@'localhost';

