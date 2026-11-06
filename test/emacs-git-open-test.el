;;; emacs-git-open-test.el --- Tests for emacs-git-open  -*- lexical-binding: t -*-

(require 'emacs-git-open)
(require 'eieio)

;; Mock class for testing magit-blame-chunk functionality
(defclass emacs-git-open-test--mock-blame-chunk ()
  ((orig-rev :initarg :orig-rev
             :documentation "The original revision SHA."))
  "Mock blame chunk for testing.")

(ert-deftest emacs-git-open--split-remote-url-test ()
  (should (equal '("github.com" . "tombonan/emacs-git-open.git")
                 (emacs-git-open--split-remote-url "git@github.com:tombonan/emacs-git-open.git")))
  (should (equal '("gitlab.corp.example.com" . "group/subgroup/team/project.git")
                 (emacs-git-open--split-remote-url
                  "git@gitlab.corp.example.com:group/subgroup/team/project.git")))
  (should (equal '("gitlab.corp.example.com" . "group/subgroup/project.git")
                 (emacs-git-open--split-remote-url
                  "ssh://git@gitlab.corp.example.com:7000/group/subgroup/project.git")))
  (should (equal '("github.com" . "tombonan/emacs-git-open.git")
                 (emacs-git-open--split-remote-url "https://github.com/tombonan/emacs-git-open.git")))
  (should-error (emacs-git-open--split-remote-url "not-a-remote-url") :type 'error))

(ert-deftest emacs-git-open--parse-remote-test ()
  (should (equal "https://github.com/tombonan/emacs-git-open"
                 (emacs-git-open--parse-remote "git@github.com:tombonan/emacs-git-open.git")))
  (should (equal "https://github.com/tombonan/emacs-git-open"
                 (emacs-git-open--parse-remote "https://github.com/tombonan/emacs-git-open.git")))
  (should (equal "https://gitlab.corp.example.com/group/subgroup/team/project"
                 (emacs-git-open--parse-remote
                  "git@gitlab.corp.example.com:group/subgroup/team/project.git")))
  (should (equal "https://gitlab.corp.example.com/group/subgroup/project"
                 (emacs-git-open--parse-remote
                  "ssh://git@gitlab.corp.example.com:7000/group/subgroup/project.git"))))

(ert-deftest emacs-git-open--remote-host-test ()
  (should (equal "github.com"
                 (emacs-git-open--remote-host "https://github.com/tombonan/emacs-git-open")))
  (should (equal "gitlab.corp.example.com"
                 (emacs-git-open--remote-host
                  "https://gitlab.corp.example.com/group/subgroup/project"))))

(ert-deftest emacs-git-open--detect-provider-test ()
  (should (eq 'github (emacs-git-open--detect-provider "github.com")))
  (should (eq 'gitlab (emacs-git-open--detect-provider "gitlab.com")))
  (should (eq 'gitlab (emacs-git-open--detect-provider "gitlab.corp.example.com")))
  (should (eq 'github (emacs-git-open--detect-provider "git.example.com"))))

(ert-deftest emacs-git-open--provider-test ()
  (with-mock
    (stub magit-git-string => "gitlab")
    (should (eq 'gitlab (emacs-git-open--provider "git.example.com"))))
  (with-mock
    (stub magit-git-string => nil)
    (stub emacs-git-open--detect-provider => 'github)
    (should (eq 'github (emacs-git-open--provider "git.example.com")))))

(ert-deftest emacs-git-open--provider-config-get-test ()
  (should (equal "blob" (emacs-git-open--provider-config-get 'github 'blob)))
  (should (equal "blame" (emacs-git-open--provider-config-get 'github 'blame)))
  (should (equal "commit" (emacs-git-open--provider-config-get 'github 'commit)))
  (should (equal "-/blob" (emacs-git-open--provider-config-get 'gitlab 'blob)))
  (should (equal "-/blame" (emacs-git-open--provider-config-get 'gitlab 'blame)))
  (should (equal "-/commit" (emacs-git-open--provider-config-get 'gitlab 'commit))))

(ert-deftest emacs-git-open--encode-ref-test ()
  (should (equal "feature%25foo" (emacs-git-open--encode-ref "feature%foo")))
  (should (equal "10-fix%23bug" (emacs-git-open--encode-ref "10-fix#bug"))))

(ert-deftest emacs-git-open--current-branch-test ()
  (with-mock
    (stub magit-get-current-branch => "main")
    (should (equal "main" (emacs-git-open--current-branch)))))

(ert-deftest emacs-git-open--remote-file-url-test ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--get-latest-sha => "1c0ad582e81748d38dfe1f1e1c9f43a96d39613a")
    (should
     (equal "https://github.com/tombonan/emacs-git-open/blob/1c0ad582e81748d38dfe1f1e1c9f43a96d39613a/README.md"
            (emacs-git-open--remote-file-url 'blob)))))

(ert-deftest emacs-git-open--remote-file-url-test-view-mode ()
  (with-mock
   (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
   (stub emacs-git-open--provider => 'github)
   (stub emacs-git-open--relative-file-path => "README.md")
   (stub emacs-git-open--get-latest-sha => "1c0ad582e81748d38dfe1f1e1c9f43a96d39613a")
    (should (equal
             "https://github.com/tombonan/emacs-git-open/blame/1c0ad582e81748d38dfe1f1e1c9f43a96d39613a/README.md"
             (emacs-git-open--remote-file-url 'blame)))))

(ert-deftest emacs-git-open--remote-file-url-test-tree-path ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--relative-file-path => "README.md")
    (should (equal "https://github.com/tombonan/emacs-git-open/blob/master/README.md"
                   (emacs-git-open--remote-file-url 'blob "master")))))

(ert-deftest emacs-git-open--remote-file-url-test-with-region ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--get-latest-sha => "1c0ad582e81748d38dfe1f1e1c9f43a96d39613a")
    (stub region-active-p => t)
    (stub line-number-at-pos => 16)
    (stub region-beginning => 16)
    (stub region-end => 16)
    (should (equal "https://github.com/tombonan/emacs-git-open/blob/1c0ad582e81748d38dfe1f1e1c9f43a96d39613a/README.md#L16-L16"
                   (emacs-git-open--remote-file-url 'blob)))))

(ert-deftest emacs-git-open--remote-file-url-test-gitlab ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://gitlab.corp.example.com/group/subgroup/project")
    (stub emacs-git-open--provider => 'gitlab)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--get-latest-sha => "1c0ad582e81748d38dfe1f1e1c9f43a96d39613a")
    (should
     (equal "https://gitlab.corp.example.com/group/subgroup/project/-/blob/1c0ad582e81748d38dfe1f1e1c9f43a96d39613a/README.md"
            (emacs-git-open--remote-file-url 'blob)))))

(ert-deftest emacs-git-open--remote-file-url-test-gitlab-blame ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://gitlab.corp.example.com/group/subgroup/project")
    (stub emacs-git-open--provider => 'gitlab)
    (stub emacs-git-open--relative-file-path => "README.md")
    (should (equal "https://gitlab.corp.example.com/group/subgroup/project/-/blame/main/README.md"
                   (emacs-git-open--remote-file-url 'blame "main")))))

(ert-deftest emacs-git-open--remote-file-url-test-gitlab-with-region ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://gitlab.corp.example.com/group/subgroup/project")
    (stub emacs-git-open--provider => 'gitlab)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--get-latest-sha => "1c0ad582e81748d38dfe1f1e1c9f43a96d39613a")
    (stub region-active-p => t)
    (stub line-number-at-pos => 16)
    (stub region-beginning => 10)
    (stub region-end => 16)
    (should (equal "https://gitlab.corp.example.com/group/subgroup/project/-/blob/1c0ad582e81748d38dfe1f1e1c9f43a96d39613a/README.md#L16-16"
                   (emacs-git-open--remote-file-url 'blob)))))

(ert-deftest git-open-default-branch-test ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--default-branch => "main")
    (mock (browse-url "https://github.com/tombonan/emacs-git-open/blob/main/README.md"))
    (git-open-default-branch)))

(ert-deftest git-open-current-branch-test ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--relative-file-path => "README.md")
    (stub emacs-git-open--current-branch => "feature-branch")
    (mock (browse-url "https://github.com/tombonan/emacs-git-open/blob/feature-branch/README.md"))
    (git-open-current-branch)))

(ert-deftest emacs-git-open--get-commit-sha-test ()
  (with-mock
    (stub magit-current-blame-chunk =>
          (emacs-git-open-test--mock-blame-chunk :orig-rev "2bc16018bdc5236792805abd9f545b61d67d8460"))
    (should (equal "2bc16018bdc5236792805abd9f545b61d67d8460" (emacs-git-open--get-commit-sha)))))

(ert-deftest emacs-git-open--commit-url-test ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://github.com/tombonan/emacs-git-open")
    (stub emacs-git-open--provider => 'github)
    (stub emacs-git-open--get-commit-sha => "1726757d97bc5b5db958b3437287eb765c6f57ef")
    (should (equal "https://github.com/tombonan/emacs-git-open/commit/1726757d97bc5b5db958b3437287eb765c6f57ef"
                   (emacs-git-open--commit-url)))))

(ert-deftest emacs-git-open--commit-url-test-gitlab ()
  (with-mock
    (stub emacs-git-open--parse-remote => "https://gitlab.corp.example.com/group/subgroup/project")
    (stub emacs-git-open--provider => 'gitlab)
    (stub emacs-git-open--get-commit-sha => "1726757d97bc5b5db958b3437287eb765c6f57ef")
    (should (equal "https://gitlab.corp.example.com/group/subgroup/project/-/commit/1726757d97bc5b5db958b3437287eb765c6f57ef"
                   (emacs-git-open--commit-url)))))

;; Error handling
(ert-deftest emacs-git-open--current-branch-error-test ()
  (with-mock
    (stub magit-get-current-branch => nil)
    (should-error (emacs-git-open--current-branch)
                  :type 'error)))

(ert-deftest emacs-git-open--remote-url-error-test ()
  (with-mock
    (stub magit-git-string => nil)
    (should-error (emacs-git-open--remote-url)
                  :type 'error)))

;;; emacs-git-open-test.el ends here
