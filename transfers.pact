(define-keyset 'admin-keyset (read-keyset "admin-keyset"))

(module critters 'admin-keyset
  "Collectible Crypto Critters"
  (defschema critter
    "Data defining a critter"
    genes:string
    matron-id:integer
    sire-id:integer
    generation:integer
    owner:keyset
    transferring:bool
    transfer-to:keyset
    available-to-breed:bool
  )

  (defschema countSchema
    count:integer
  )

  (deftable critters:{critter})
  (deftable countTable:{countSchema})

  (defun get-inc-count:string (k:string)
    "Incremenent row K in the count table"
    (with-read countTable k {"count" := count}
     (write countTable k {"count": (+ count 1)})
     (format "{}" [count])
    )
  )

  (defun create-critter:integer (genes:string)
    "Create a gen0 critter using GENES"
    (enforce-keyset 'admin-keyset)
    (let ((id (get-inc-count "critters")))
      (insert critters id
        { "matron-id": 0,
          "sire-id": 0,
          "generation": 0,
          "genes": genes,
          "owner": (read-keyset "admin-keyset"),
          "transferring": false,
          "transfer-to": (read-keyset "admin-keyset"),
          "available-to-breed": false
        }
      )
      id
    )
  )

  (defun show-critter:string (suffix:string critter:object{critter})
    "String representation of CRITTER appending SUFFIX"
    (bind critter { "matron-id" := m,
              "sire-id" := s,
              "generation" := gen,
              "genes" := genes,
              "owner" := o,
              "transferring" := t,
              "transfer-to" := tto
            }
      (+ (format "gen: {} matron: {} sire: {} owner: {} {} {} {}\n"
          [gen m s o t tto genes]) suffix)
    )
  )

  (defun show-generation:string (gen:integer)
    "Get all the critters in GEN generation"
    (let ((cs (select critters (where 'generation (= gen)))))
         (fold (show-critter) "" cs)
    )
  )

  (defun owner (critter-id:string)
    "Get the owner of a critter CRITTER-ID"
    (with-read critters critter-id {"owner":= o} o)
  )

  (defun transfer-critter (new-owner:keyset critter-id:string)
    "Transfer critter CRITTER-ID ownership to NEW-OWNER (Note: UNSAFE!)"
    (let ((c (read critters critter-id)))
        (enforce-keyset (at "owner" c))
        (update critters critter-id
          (+ {"owner": new-owner} c)
        )
    )
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Safe critter transfers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun set-transfer (critter-id:string transfer:bool to:keyset)
    "Set critter CRITTER-ID TRANSFER flag to TO keyset"
    ;; NOTE: This is a private helper function
    (let ((c (read critters critter-id)))
        (enforce-keyset (at "owner" c))
        (update critters critter-id
          (+ {"transferring": transfer, "transfer-to": to} c)
        )
    )
  )

  (defun initiate-transfer (new-owner:keyset critter-id:string)
    "Transfer critter CRITTER-ID ownership to NEW-OWNER safely without \
    \the possibility of the critter getting lost"
    (let ((c (read critters critter-id)))
      (enforce-keyset (at "owner" c))
      ;; We don't call transferCritter because we're not the owner
      (set-transfer critter-id true new-owner)
    )
  )

  (defun complete-transfer (critter-id:string)
    (let ((c (read critters critter-id)))
      (enforce-keyset (at "transfer-to" c))
      ;; We don't call transferCritter because we're not the owner
      (update critters critter-id
        (+ {"owner": (at "transfer-to" c)} c)
      )
      (set-transfer critter-id false (read-keyset "admin-keyset"))
    )
  )

  (defun cancel-transfer (critter-id:string)
    (let ((c (read critters critter-id)))
      (enforce-keyset (at "owner" c))
      ;; We don't call transferCritter because we're not the owner
      (set-transfer critter-id false (read-keyset "admin-keyset"))
    )
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Critter breeding
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (defun set-breeding (critter-id:string flag:bool)
    "Set a critter's breeding flag"
    ;; NOTE: This is a private helper function
    (let ((c (read critters critter-id)))
        (enforce-keyset (at "owner" c))
        (update critters critter-id
          (+ {"breeding": flag} c)
        )
    )
  )

  (defun solicit-mate (critter-id:string)
    "Make your critter available for breeding"
    (let ((c (read critters critter-id)))
      (enforce-keyset (at "owner" c))
      ;; We don't call transferCritter because we're not the owner
      (set-breeding critter-id true)
    )
  )

  (defun max (a b)
    (if (> a b) a b)
  )

  (defun combine-genes (a:string b:string)
    "Create child genes from two sets of parent genes"
    (let* ((ind 5)
          (left (take ind a))
          (right (drop ind b))
         )
      (+ left right)
    )
  )

  (defun breed (critter-id-a:string critter-id-b:string)
    "Make your critter available for breeding"
    (let ((a (read critters critter-id-a))
          (b (read critters critter-id-b))
         )
      (enforce-keyset (at "owner" b))
      (enforce (at "breeding" a) "That critter is not available for breeding")
      ;; We don't call transferCritter because we're not the owner
      (let ((i (get-inc-count "critters")))
        (insert critters (format "{}" [i])
          { "matronId": (format "{}" critter-id-a),
            "sireId": (format "{}" critter-id-b),
            "generation": (+ 1 (max (at "generation" a) (at "generation" b))),
            "genes": (combine-genes (at "genes" a) (at "genes" b)),
            "owner": (at "owner" a),
            "transferring": false,
            "transferTo": (read-keyset "admin-keyset"),
            "available-to-breed": false
          }
        )
        i
      )
    )
  )

  (defun cancel (critter-id:string)
    "Take critter CRITTER-ID off the breeding market"
    (let ((c (read critters critter-id)))
      (enforce-keyset (at "owner" c))
      ;; We don't call transferCritter because we're not the owner
      (set-breeding critter-id false)
    )
  )
)

(create-table critters)
(create-table countTable)
(insert countTable "critters" {"count":0})
