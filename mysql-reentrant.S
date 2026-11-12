	.file	"mysql-reentrant.S"
	.machinemode zarch
	.machine "z13"
	
	.include	"system.def"
	
	.text
	.align	8
	.global connexion
	.type	connexion, @function

connexion:								// en sortie : R2 = MYSQL* ou 0 si erreur
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	XGR		R4, R4						// groups, NULL
	XGR		R3, R3						// argv, NULL
	XGR		R2, R2						// argc, aucun argument
	BRASL	R14, mysql_server_init@PLT	// int mysql_server_init(int argc, char **argv, char **groups)
	LTGR	R2, R2						// r2 = code retour
	JE		SERVER_INIT_OK				// si succès
	LARL	R2, .LC0					// adresse du message ci-dessous
	BRASL	R14, puts@PLT				// if ( mysql_library_init ( 0, NULL, NULL ) ) { fprintf(stderr, "Initialisation de 'MySQL client library' impossible.\n"); exit ( EXIT_FAILURE ); }
	LGFI	R2, 1						// EXIT_FAILURE
	BRASL	R14, exit@PLT				// exit ( EXIT_FAILURE );
	
SERVER_INIT_OK:
	BRASL	R14, mysql_init@PLT			// mysql_init()
	LGR		R10, R2						// pointeur sur une structure, sauvé dans R10
	LTGR	R10, R10
	JNE		INIT_OK						// pointeur non NULL, donc c'est bon
	LARL	R2, .LC1					// Init failed...
	BRASL	R14, puts@PLT
	XGR		R2, R2						// pointeur nul
	J		CEND
	
INIT_OK:
	LARL	R4, MY_CNF					// ./my.cnf
	LGFI	R3, 4						// MYSQL_READ_DEFAULT_FILE (argument type: char *) Read options from the named option file instead of from my.cnf.
	LGR		R2, R10						// pointe vers la structure
	BRASL	R14, mysql_options@PLT		// int mysql_options ( mysql, MYSQL_READ_DEFAULT_FILE, (void *)"./my.cnf" ); R2 ignoré
	LTGR	R2, R2
	JE		OPTIONS_OK
	LARL	R2, ERR_OPTION
	BRASL	R14, puts@PLT
	XGR		R2, R2
	J		CEND
	
OPTIONS_OK:
	LGFI	R6, 0						// default data base = NULL
	LGFI	R5, 0						// password = NULL
	LGFI	R4, 0						// user = NULL
	LGFI	R3, 0						// hostname = NULL
	LGR		R2, R10						// structure MYSQL*
	BRASL	R14, mysql_real_connect@PLT	// if ( !mysql_real_connect ( mysql,   NULL, NULL, NULL, NULL, 0 port number, 0 for default, NULL socket file or named pipe name, CLIENT_FOUND_ROWS connection flags
	LTGR	R2, R2
	JNE		REAL_CONNECT_OK
	LARL	R2, ERR_CONNEXION
	BRASL	R14, puts@PLT
	XGR		R2, R2						// pointeur nul
	J		CEND
	
REAL_CONNECT_OK:
	LGR		R2, R10						// MYSQL*
CEND:
	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
	BR		R14
	
	.text
	.align	8
	.global traitement_requete
	.type	traitement_requete, @function
	
traitement_requete:								// en entrée R2 = MYSQL*, R3 = REQUETE, R4 = chaine sortante - en sortie R2 = 0 si requête non aboutie
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	LGR		R10, R2						// sauver R2 MYSQL*
	LGR		R6, R4						// adresse chaine sortante
	BRASL	R14, mysql_query@PLT
	LTGR	R2, R2
	JE		QUERY_OK
	LGR		R2, R10
	BRASL	R14, mysql_error@PLT		// retourne char* en R2
	LGR		R3, R2
	LARL	R2, ERR_REQUETE				// query failed
	BRASL	R14, printf@PLT
	XGR		R2, R2
	J		TEND
	
QUERY_OK:
	LGR		R2, R10
	BRASL	R14, mysql_store_result@PLT
	LGR		R9, R2						// R9 = MYSQL_RES
	LTGR	R2, R2						// R2 = MYSQL_RES
	JNE		STORE_RESULT_OK
	STC 	R2, 0(R6)					// resultat NULL
	J		RESULTAT_VIDE
	
STORE_RESULT_OK:
	XGR		R0, R0
	LARL	R5, ACCOLADE_GAUCHE
	MVST	R6, R5
	LGR		R2, R9
	BRASL	R14, mysql_num_fields@PLT
	LGR		R8, R2						// R8 = nombre de colonnes
	LGR		R2, R9
	BRASL	R14, mysql_num_rows@PLT
	LGR		R7, R2						// R7 = nombre de lignes
LIGNE:
	LGR		R2, R9
	BRASL	R14, mysql_fetch_row@PLT
	LTGR	R2, R2
	JNE		LIGNE_OK
	STC 	R2, 0(R6)					// resultat NULL
	J		RESULTAT_VIDE
			
LIGNE_OK:
	XGR		R11, R11
	LGR		R13, R8						// nombre de colonnes
	LGR		R12, R2						// sauver R2 (MYSQL_RES)
	XGR		R0, R0
	LARL	R5, CROCHET_GAUCHE
	MVST	R6, R5
COLONNE:
	LARL	R5, APOSTROPHE
	MVST	R6, R5
	LG		R3, 0(R11, R12)
M1:	MVST	R6, R3
	JO		M1
	LARL	R5, APOSTROPHE
	MVST	R6, R5
	CLGFI	R13, 1
	JNH		DERNIER_CHAMP
	LARL	R5, VIRGULE
	MVST	R6, R5
	AGFI	R11, 8
DERNIER_CHAMP:
	BRCTG	R13, COLONNE
	LARL	R5, CROCHET_DROIT
	MVST	R6, R5
	BRCTG	R7, LIGNE
	LGR		R2, R9						// R2 = MYSQL_RES
	BRASL	R14, mysql_free_result@PLT
	XGR		R0, R0
	LARL	R5, ACCOLADE_DROITE
	MVST	R6, R5
	LARL	R5, NEW_LINE
	MVST	R6, R5
TEND:
	LGFI	R2, 1						// OK
RESULTAT_VIDE:
	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
	BR		R14

	.align	8
	.global deconnexion
	.type	deconnexion, @function
	
deconnexion:						// en entrée : R2 = MYSQL*
	STMG	R6, R15, 48(R15)
	LAY		R15, -160(R15)
	BRASL	R14, mysql_close@PLT
	BRASL	R14, mysql_server_end@PLT
	LAY		R15, 160(R15)
	LMG		R6, R15, 48(R15)
	BR		R14

	.section	.rodata
	.align	2
.LC0:
	.string	"Initialisation de 'MySQL client library' impossible.\n"
	.align	2
.LC1:
	.string	"Erreur d'initialisation, problème mémoire ?"
	.align	2
MY_CNF:
	.string	"./my.cnf"
	.align	2
ERR_CONNEXION:
	.string	"Erreur de connexion.\n"
	.align	2
ERR_OPTION:
	.asciz	"Mauvaise option.\n"
	.align	2
ERR_REQUETE:
	.asciz	"Requête invalide %s.\n"
	.align	2
ACCOLADE_GAUCHE:
	.asciz	"{"
ACCOLADE_DROITE:
	.asciz	"}"
CROCHET_GAUCHE:
	.asciz	"["
CROCHET_DROIT:
	.asciz	"]"
VIRGULE:
	.asciz	","
APOSTROPHE:
	.asciz	"'"
NEW_LINE:
	.asciz	"\n"
		
	.section	.note.GNU-stack,"",@progbits
