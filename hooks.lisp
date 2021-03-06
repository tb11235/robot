(in-package :robot)

(defparameter *custom-hooks* '())

#|
(defmacro defhook (message-type &rest body)
  `(progn (defmethod custom-hook ((message ,message-type))
	    ,@body)
	  (push ,message-type *custom-hooks*)))
|#

(defgeneric custom-hook (message)
  (:documentation "Custom action to be executed upon reception of the IRC message."))

(defgeneric load-custom-hooks (connection)
  (:documentation "Load list of user-defined hooks to CONNECTION."))

;(defhook (intern "irc-join-message")
;    (unless (self-message-p message)
;      (with-slots (source arguments) message
;	(say message (format nil "Welcome to ~a, ~a." (first arguments) source)))))

(defmethod custom-hook ((message irc-nick-message))
  (unless (or (self-message-p message)
	      (not (authorized-p (source message))))
    (let ((active-user-info (gethash source *active-users*)))
      )))

(defmethod custom-hook ((message irc-join-message))
  (unless (self-message-p message)
    (with-slots (source arguments) message
      (say message (format nil "Welcome to ~a, ~a." (first arguments) source)))))

(defmethod custom-hook ((message irc-part-message))
  (unless (self-message-p message)
    (quit-response message)))

(defmethod custom-hook ((message irc-quit-message))
  (unless (self-message-p message)
    (quit-response message)))

(defun quit-response (message)
  (with-slots (source arguments) message
    (say message (format nil "~a has left the building!" source))))

(defmethod custom-hook ((message irc-kill-message))
  (with-slots (connection) message
    (make-bot (server-name connection)
	      :nick (nickname (user connection))
	      :channels (channels connection))))

(defmethod custom-hook ((message irc-kick-message))
  (with-slots (arguments connection) message
   (let ((channel (find-channel connection
				(first arguments))))
     (join connection channel))))

(defmethod custom-hook ((message irc-err_nicknameinuse-message))
  (with-slots (connection) message
    (nick connection (make-nick))))

(defmethod custom-hook ((message irc-privmsg-message))
  (unless (self-message-p message)
    (with-slots (source) message
     (search-command-table message)
     (speak message)
     (when (gethash source *pounce-list*)
       (say message (format nil "~a: You have ~a memos." source (gethash source *pounce-list*)))
       (remhash source *pounce-list*)))))

(defmethod custom-hook ((message irc-topic-message))
  (with-slots (arguments connection) message
    (let ((channel (find-channel connection (first arguments))))
      (when (and channel (topic channel))
	(save-topic (first arguments) (topic channel)))))) 

(defmethod custom-hook ((message irc-err_chanoprivsneeded-message))
  (say message (format nil "I require channel operator privileges.")))

;(defmethod custom-hook ((message irc-rpl_isupport-message))
;  (let ((server-options (make-hash-table)))
;    (split-whitespace message)))

(defmethod load-custom-hooks ((connection connection))
  (remove-all-hooks connection)
  (add-default-hooks connection)
  (dolist (message '(irc-join-message
		     irc-part-message
		     irc-quit-message
		     irc-kill-message
		     irc-kick-message
		     irc-err_nicknameinuse-message
		     irc-privmsg-message
		     irc-topic-message
                     irc-err_chanoprivsneeded-message))
    (add-hook connection message #'custom-hook)))
