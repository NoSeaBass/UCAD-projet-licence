package com.model;

public class ConnexionModel {
    private Personne personne;
    private String email;
    private String password;

    public ConnexionModel(Personne personne, String email, String password) {
        this.personne = personne;
        this.email = email;
        this.password = password;
    }

    public Personne getPersonne() {
        return personne;
    }

    /*
    Dans le futur faudra ajouter la fonctionnalité "se souvenir de moi"
    */

}
